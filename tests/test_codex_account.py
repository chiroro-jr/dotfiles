import base64
import importlib.util
import json
import tempfile
import time
import unittest
from pathlib import Path


HELPER = (
    Path(__file__).parents[1]
    / "stow/fish/.config/fish/functions/__codex_account.py"
)
SPEC = importlib.util.spec_from_file_location("codex_account_helper", HELPER)
assert SPEC and SPEC.loader
account = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(account)


def jwt(account_id: str, email: str, plan: str, exp: int) -> str:
    def encode(value: dict) -> str:
        raw = json.dumps(value, separators=(",", ":")).encode()
        return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()

    return ".".join(
        (
            encode({"alg": "none"}),
            encode(
                {
                    "exp": exp,
                    "email": email,
                    "https://api.openai.com/auth": {
                        "chatgpt_account_id": account_id,
                        "chatgpt_plan_type": plan,
                    },
                }
            ),
            "signature",
        )
    )


def grant(
    account_id: str,
    refresh: str,
    *,
    email: str = "person@example.com",
    plan: str = "business",
    expires_in: int = 3600,
) -> dict:
    access = jwt(account_id, email, plan, int(time.time()) + expires_in)
    return {
        "auth_mode": "chatgpt",
        "tokens": {
            "id_token": access,
            "access_token": access,
            "refresh_token": refresh,
            "account_id": account_id,
        },
        "last_refresh": "2026-01-01T00:00:00Z",
    }


def common_args(root: Path) -> list[str]:
    return [
        "--accounts-home",
        str(root / "store/accounts"),
        "--codex-live",
        str(root / "codex/auth.json"),
        "--pi-live",
        str(root / "pi/auth.json"),
        "--opencode-live",
        str(root / "opencode/auth.json"),
        "--zed-live",
        account.ZED_LIVE_SENTINEL,
    ]


class CodexAccountTests(unittest.TestCase):
    def test_workspace_collision_gets_stable_suffix(self):
        with tempfile.TemporaryDirectory() as tmp:
            accounts_home = Path(tmp) / "accounts"
            accounts_home.mkdir()
            first = grant("workspace-one", "refresh-one")
            second = grant("workspace-two", "refresh-two")
            first_name = account._slot_name(first, accounts_home)
            self.assertEqual(first_name, "person@example.com.business")
            account.write_saved_grant(accounts_home / f"{first_name}.json", first)

            second_name = account._slot_name(second, accounts_home)
            self.assertTrue(second_name.startswith("person@example.com.business."))
            self.assertNotEqual(first_name, second_name)
            self.assertEqual(second_name, account._slot_name(second, accounts_home))

    def test_non_file_codex_storage_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            codex_home = Path(tmp)
            (codex_home / "config.toml").write_text(
                'cli_auth_credentials_store = "keyring"\n'
            )
            with self.assertRaises(SystemExit):
                account.check_codex_storage(codex_home)

    def test_refresh_failure_keeps_recovery_and_sync_consumes_it(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            args = common_args(root)
            accounts_home = root / "store/accounts"
            accounts_home.mkdir(parents=True)
            old = grant("workspace-one", "old-refresh", expires_in=60)
            account.write_pi_live(root / "pi/auth.json", old)
            account.write_saved_grant(
                accounts_home / "person@example.com.business.json", old
            )

            new_access = jwt(
                "workspace-one",
                "person@example.com",
                "business",
                int(time.time()) + 7200,
            )
            original_refresh = account._refresh_chatgpt_token
            original_live = account._live_chatgpt_data
            original_zed_write = account.write_zed_live
            zed_state = old
            account._refresh_chatgpt_token = lambda _token, as_json=False: {
                "access_token": new_access,
                "id_token": new_access,
                "refresh_token": "new-refresh",
                "expires_in": 7200,
            }
            account._live_chatgpt_data = (
                lambda path: zed_state
                if account.is_zed_live(path)
                else original_live(path)
            )
            account.write_zed_live = lambda _path, _data: (_ for _ in ()).throw(
                RuntimeError("locked keyring")
            )
            try:
                with self.assertRaises(SystemExit):
                    account.cmd_refresh(args)
                pending = account.load_pending_refresh(accounts_home)
                self.assertIsNotNone(pending)
                self.assertEqual(account.grant_refresh(pending), "new-refresh")

                def save_zed(_path, data):
                    nonlocal zed_state
                    zed_state = data

                account.write_zed_live = save_zed
                account.cmd_sync(args)
                self.assertFalse(account.pending_refresh_path(accounts_home).exists())
                self.assertEqual(account.grant_refresh(zed_state), "new-refresh")
                self.assertEqual(
                    account.grant_refresh(json.loads((root / "codex/auth.json").read_text())),
                    "new-refresh",
                )
            finally:
                account._refresh_chatgpt_token = original_refresh
                account._live_chatgpt_data = original_live
                account.write_zed_live = original_zed_write

    def test_refresh_saved_does_not_fill_missing_live_destinations(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            args = common_args(root)
            accounts_home = root / "store/accounts"
            accounts_home.mkdir(parents=True)
            saved_name = "person@example.com.business"
            old = grant("workspace-one", "old-refresh", expires_in=60)
            account.write_saved_grant(accounts_home / f"{saved_name}.json", old)
            new_access = jwt(
                "workspace-one",
                "person@example.com",
                "business",
                int(time.time()) + 7200,
            )
            original_refresh = account._refresh_chatgpt_token
            account._refresh_chatgpt_token = lambda _token, as_json=False: {
                "access_token": new_access,
                "id_token": new_access,
                "refresh_token": "new-refresh",
                "expires_in": 7200,
            }
            try:
                account.cmd_refresh([*args, "--name", saved_name])
            finally:
                account._refresh_chatgpt_token = original_refresh

            self.assertFalse((root / "codex/auth.json").exists())
            self.assertFalse((root / "pi/auth.json").exists())
            self.assertFalse((root / "opencode/auth.json").exists())
            self.assertFalse(account.pending_refresh_path(accounts_home).exists())
            refreshed = json.loads((accounts_home / f"{saved_name}.json").read_text())
            self.assertEqual(account.grant_refresh(refreshed), "new-refresh")

    def test_missing_internal_option_value_is_a_normal_cli_error(self):
        with self.assertRaises(SystemExit):
            account._parse_common_paths(["--accounts-home"])

    def test_pending_refresh_blocks_new_mutations_until_sync(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            accounts_home = root / "store/accounts"
            accounts_home.mkdir(parents=True)
            recovery = grant("workspace-one", "fresh-refresh")
            account.write_pending_refresh(accounts_home, recovery)

            with self.assertRaises(SystemExit):
                account.main(
                    [
                        "require-no-pending",
                        "--action",
                        "login",
                        *common_args(root),
                    ]
                )
            self.assertEqual(
                account.grant_refresh(account.load_pending_refresh(accounts_home)),
                "fresh-refresh",
            )

    def test_usage_refresh_failure_keeps_recovery_grant(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            accounts_home = root / "store/accounts"
            accounts_home.mkdir(parents=True)
            refreshed = grant("workspace-one", "fresh-refresh")
            target = accounts_home / "person@example.com.business.json"
            original_sync = account._sync_related_token_copies
            account._sync_related_token_copies = (
                lambda *_args: (_ for _ in ()).throw(RuntimeError("locked keyring"))
            )
            try:
                with self.assertRaises(RuntimeError):
                    account._persist_usage_refresh(
                        target, refreshed, {}, accounts_home, "workspace-one"
                    )
            finally:
                account._sync_related_token_copies = original_sync

            pending = account.load_pending_refresh(accounts_home)
            self.assertIsNotNone(pending)
            self.assertEqual(account.grant_refresh(pending), "fresh-refresh")


if __name__ == "__main__":
    unittest.main()
