#!/usr/bin/env python3
import hashlib
import json
import os
import secrets
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

PI_OAUTH_CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann"
PI_OAUTH_AUTH_BASE = "https://auth.openai.com"
PI_OAUTH_AUTHORIZE_URL = f"{PI_OAUTH_AUTH_BASE}/oauth/authorize"
PI_OAUTH_TOKEN_URL = f"{PI_OAUTH_AUTH_BASE}/oauth/token"
PI_OAUTH_REDIRECT_URI = "http://localhost:1455/auth/callback"
PI_OAUTH_DEVICE_USER_CODE_URL = f"{PI_OAUTH_AUTH_BASE}/api/accounts/deviceauth/usercode"
PI_OAUTH_DEVICE_TOKEN_URL = f"{PI_OAUTH_AUTH_BASE}/api/accounts/deviceauth/token"
PI_OAUTH_DEVICE_VERIFICATION_URI = f"{PI_OAUTH_AUTH_BASE}/codex/device"
PI_OAUTH_DEVICE_REDIRECT_URI = f"{PI_OAUTH_AUTH_BASE}/deviceauth/callback"
PI_OAUTH_SCOPE = "openid profile email offline_access"
PI_OAUTH_CALLBACK_PORT = 1455
PI_OAUTH_TIMEOUT_SECONDS = 15 * 60

AGENTS = ("codex", "pi", "opencode")
LIVE_PRIORITY = ("pi", "opencode", "codex")


def die(message: str, code: int = 1) -> None:
    print(f"Error: {message}", file=sys.stderr)
    raise SystemExit(code)


def atomic_write_json(path: Path, data: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".tmp.", suffix=".json", dir=str(path.parent))
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w") as handle:
            json.dump(data, handle, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, path)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def load_json(path: Path) -> dict:
    if not str(path) or path == Path(".") or path.is_dir():
        die(f"expected a JSON file, got directory or empty path: {path}")
    try:
        data = json.loads(path.read_text())
    except FileNotFoundError:
        die(f"file not found: {path}")
    except OSError as exc:
        die(f"cannot read {path}: {exc}")
    except json.JSONDecodeError as exc:
        die(f"invalid JSON in {path}: {exc}")
    if not isinstance(data, dict):
        die(f"{path} must be a JSON object")
    return data


def try_load_json(path: Path) -> dict | None:
    try:
        data = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def b64url_decode(segment: str) -> bytes:
    padding = "=" * (-len(segment) % 4)
    return __import__("base64").urlsafe_b64decode(segment + padding)


def jwt_payload(token: str) -> dict:
    if not token or token.count(".") < 2:
        return {}
    try:
        payload = json.loads(b64url_decode(token.split(".")[1]))
    except Exception:
        return {}
    return payload if isinstance(payload, dict) else {}


def openai_auth_claims(token: str) -> dict:
    payload = jwt_payload(token)
    auth = payload.get("https://api.openai.com/auth")
    return auth if isinstance(auth, dict) else {}


def token_email(*tokens: str) -> str | None:
    for token in tokens:
        payload = jwt_payload(token)
        profile = payload.get("https://api.openai.com/profile")
        candidates = [payload.get("email")]
        if isinstance(profile, dict):
            candidates.append(profile.get("email"))
        for candidate in candidates:
            if isinstance(candidate, str) and "@" in candidate:
                return candidate.strip().lower()
    return None


def token_client_id(token: str) -> str | None:
    payload = jwt_payload(token)
    client_id = payload.get("client_id")
    return client_id if isinstance(client_id, str) else None


def pi_oauth_from_data(data: dict) -> dict:
    if data.get("type") == "oauth" and data.get("access") and data.get("refresh"):
        return data
    for key in ("openai-codex", "openai"):
        oauth = data.get(key)
        if isinstance(oauth, dict) and (oauth.get("access") or oauth.get("refresh")):
            return oauth
    return {}


def identity_from_codex(data: dict) -> dict:
    tokens = data.get("tokens") if isinstance(data.get("tokens"), dict) else {}
    access = tokens.get("access_token") or ""
    id_token = tokens.get("id_token") or ""
    auth = openai_auth_claims(access) or openai_auth_claims(id_token)
    account_id = tokens.get("account_id") or auth.get("chatgpt_account_id")
    return {
        "account_id": account_id,
        "plan": auth.get("chatgpt_plan_type"),
        "email": token_email(id_token, access),
        "client_id": token_client_id(access) or token_client_id(id_token),
        "has_refresh": bool(tokens.get("refresh_token")),
        "auth_mode": data.get("auth_mode") or "chatgpt",
    }


def identity_from_pi(data: dict) -> dict:
    oauth = pi_oauth_from_data(data)
    access = oauth.get("access") or ""
    auth = openai_auth_claims(access)
    return {
        "account_id": oauth.get("accountId") or auth.get("chatgpt_account_id"),
        "plan": auth.get("chatgpt_plan_type"),
        "email": token_email(access),
        "client_id": token_client_id(access),
        "has_refresh": bool(oauth.get("refresh")),
        "auth_mode": oauth.get("type") or "oauth",
    }


def looks_like_codex(data: dict) -> bool:
    tokens = data.get("tokens")
    return isinstance(tokens, dict) and bool(tokens.get("access_token") or tokens.get("refresh_token"))


def looks_like_pi(data: dict) -> bool:
    oauth = pi_oauth_from_data(data)
    return oauth.get("type") == "oauth" and bool(oauth.get("access") or oauth.get("refresh"))


def identity_from_any(data: dict) -> dict:
    if looks_like_codex(data):
        return identity_from_codex(data)
    return identity_from_pi(data)


def identity_from_saved(agent: str, data: dict) -> dict:
    if looks_like_codex(data):
        return identity_from_codex(data)
    if looks_like_pi(data):
        return identity_from_pi(data)
    return identity_from_codex(data) if agent == "codex" else identity_from_pi(data)


def to_codex(data: dict) -> dict:
    if looks_like_codex(data):
        tokens = dict(_codex_tokens(data))
        access = str(tokens.get("access_token") or "")
        refresh = str(tokens.get("refresh_token") or "")
        id_token = str(tokens.get("id_token") or "") or access
        account_id = str(tokens.get("account_id") or openai_auth_claims(access).get("chatgpt_account_id") or "")
        out = dict(data)
        out["auth_mode"] = data.get("auth_mode") or "chatgpt"
        out["tokens"] = {
            "id_token": id_token,
            "access_token": access,
            "refresh_token": refresh,
            "account_id": account_id,
        }
        if data.get("last_refresh"):
            out["last_refresh"] = data["last_refresh"]
        return out

    oauth = pi_oauth_from_data(data)
    access = str(oauth.get("access") or "")
    refresh = str(oauth.get("refresh") or "")
    account_id = str(oauth.get("accountId") or openai_auth_claims(access).get("chatgpt_account_id") or "")
    last_refresh = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    expires_ms = oauth.get("expires")
    if isinstance(expires_ms, (int, float)) and expires_ms > 0:
        last_refresh = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(max(0, expires_ms / 1000 - 864000)))
    return {
        "auth_mode": "chatgpt",
        "tokens": {
            "id_token": access,
            "access_token": access,
            "refresh_token": refresh,
            "account_id": account_id,
        },
        "last_refresh": last_refresh,
    }


def to_pi_oauth(data: dict) -> dict:
    if looks_like_codex(data):
        tokens = _codex_tokens(data)
        access = str(tokens.get("access_token") or "")
        refresh = str(tokens.get("refresh_token") or "")
        account_id = str(tokens.get("account_id") or openai_auth_claims(access).get("chatgpt_account_id") or "")
        exp = jwt_payload(access).get("exp")
        expires = int(exp * 1000) if isinstance(exp, (int, float)) else int(time.time() * 1000) + 864000 * 1000
        return {
            "type": "oauth",
            "access": access,
            "refresh": refresh,
            "expires": expires,
            "accountId": account_id,
        }
    oauth = dict(pi_oauth_from_data(data))
    oauth["type"] = "oauth"
    return oauth


def grant_account_id(data: dict) -> str:
    return str(identity_from_any(data).get("account_id") or "")


def grant_refresh(data: dict) -> str:
    if looks_like_codex(data):
        return str(_codex_tokens(data).get("refresh_token") or "")
    return str(pi_oauth_from_data(data).get("refresh") or "")


def grant_access_exp(data: dict) -> float:
    if looks_like_codex(data):
        access = str(_codex_tokens(data).get("access_token") or "")
    else:
        access = str(pi_oauth_from_data(data).get("access") or "")
    exp = jwt_payload(access).get("exp")
    return float(exp) if isinstance(exp, (int, float)) else 0.0


def write_codex_live(path: Path, data: dict) -> None:
    canonical = to_codex(data)
    existing = try_load_json(path) if path.is_file() else None
    out = dict(existing) if existing else {}
    out["auth_mode"] = canonical.get("auth_mode") or "chatgpt"
    out["tokens"] = canonical["tokens"]
    if canonical.get("last_refresh"):
        out["last_refresh"] = canonical["last_refresh"]
    atomic_write_json(path, out)
    os.chmod(path, 0o600)


def write_pi_live(path: Path, data: dict) -> None:
    live = try_load_json(path) if path.is_file() else None
    out = dict(live) if live else {}
    out["openai-codex"] = to_pi_oauth(data)
    path.parent.mkdir(parents=True, exist_ok=True)
    atomic_write_json(path, out)
    os.chmod(path, 0o600)


def write_opencode_live(path: Path, data: dict) -> None:
    live = try_load_json(path) if path.is_file() else None
    out = dict(live) if live else {}
    out["openai"] = to_pi_oauth(data)
    path.parent.mkdir(parents=True, exist_ok=True)
    atomic_write_json(path, out)
    os.chmod(path, 0o600)


def write_saved_grant(path: Path, data: dict) -> None:
    atomic_write_json(path, to_codex(data))
    os.chmod(path, 0o600)


def write_all_lives(
    data: dict,
    codex_live: Path | None,
    pi_live: Path | None,
    opencode_live: Path | None = None,
) -> None:
    if codex_live is not None:
        write_codex_live(codex_live, data)
    if pi_live is not None:
        write_pi_live(pi_live, data)
    if opencode_live is not None:
        write_opencode_live(opencode_live, data)


def write_both_lives(
    data: dict,
    codex_live: Path | None,
    pi_live: Path | None,
    opencode_live: Path | None = None,
    *,
    update_codex: bool = True,
    update_pi: bool = True,
    update_opencode: bool = True,
) -> None:
    if update_codex and codex_live is not None:
        write_codex_live(codex_live, data)
    if update_pi and pi_live is not None:
        write_pi_live(pi_live, data)
    if update_opencode and opencode_live is not None:
        write_opencode_live(opencode_live, data)


def require_chatgpt_codex(data: dict, source: str) -> dict:
    identity = identity_from_codex(data)
    tokens = data.get("tokens") if isinstance(data.get("tokens"), dict) else {}
    if not tokens.get("access_token") or not tokens.get("refresh_token"):
        die(f"{source} is not a ChatGPT Codex login with access and refresh tokens.")
    if not identity.get("account_id"):
        die(f"{source} has no chatgpt account id.")
    return identity


def require_pi_oauth(data: dict, source: str) -> dict:
    oauth = pi_oauth_from_data(data)
    if oauth.get("type") != "oauth" or not oauth.get("access") or not oauth.get("refresh"):
        die(f"{source} has no openai-codex OAuth login.")
    identity = identity_from_pi({"openai-codex": oauth} if oauth.get("type") == "oauth" else data)
    if not identity.get("account_id"):
        die(f"{source} has no chatgpt account id.")
    return identity


def print_identity(identity: dict) -> None:
    print(
        json.dumps(
            {
                "account_id": identity.get("account_id") or "",
                "plan": identity.get("plan") or "unknown",
                "email": identity.get("email") or "",
                "client_id": identity.get("client_id") or "",
            }
        )
    )


def extract_pi_oauth(pi_path: Path, out_path: Path) -> dict:
    pi = load_json(pi_path)
    identity = require_pi_oauth(pi, str(pi_path))
    atomic_write_json(out_path, pi_oauth_from_data(pi))
    os.chmod(out_path, 0o600)
    return identity


def apply_pi_oauth(blob_path: Path, pi_path: Path) -> dict:
    blob = load_json(blob_path)
    identity = require_pi_oauth(blob, str(blob_path))
    pi = {}
    if pi_path.exists():
        pi = load_json(pi_path)
    pi["openai-codex"] = pi_oauth_from_data(blob)
    atomic_write_json(pi_path, pi)
    os.chmod(pi_path, 0o600)
    return identity


def _b64url_nopad(data: bytes) -> str:
    return __import__("base64").urlsafe_b64encode(data).rstrip(b"=").decode()


def _pkce_pair() -> tuple[str, str]:
    verifier = _b64url_nopad(os.urandom(32))
    challenge = _b64url_nopad(hashlib.sha256(verifier.encode()).digest())
    return verifier, challenge


def _http_json(url: str, payload: dict, content_type: str) -> dict:
    if content_type == "json":
        body = json.dumps(payload).encode()
        headers = {"Content-Type": "application/json"}
    else:
        body = urllib.parse.urlencode(payload).encode()
        headers = {"Content-Type": "application/x-www-form-urlencoded"}
    request = urllib.request.Request(url, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")
        die(f"OpenAI Codex OAuth request failed ({exc.code}): {detail or exc.reason}")
    except urllib.error.URLError as exc:
        die(f"OpenAI Codex OAuth request failed: {exc.reason}")
    return {}


def _token_from_code(code: str, verifier: str, redirect_uri: str) -> dict:
    data = _http_json(
        PI_OAUTH_TOKEN_URL,
        {
            "grant_type": "authorization_code",
            "client_id": PI_OAUTH_CLIENT_ID,
            "code": code,
            "code_verifier": verifier,
            "redirect_uri": redirect_uri,
        },
        "form",
    )
    access = data.get("access_token")
    refresh = data.get("refresh_token")
    expires_in = data.get("expires_in")
    if not access or not refresh or not isinstance(expires_in, (int, float)):
        die(f"OpenAI Codex token response missing fields: {json.dumps(data)}")
    return {
        "type": "oauth",
        "access": access,
        "refresh": refresh,
        "expires": int(time.time() * 1000) + int(expires_in) * 1000,
        "accountId": openai_auth_claims(access).get("chatgpt_account_id") or "",
    }


def _oauth_blob_from_token(token: dict) -> dict:
    if not token.get("accountId"):
        die("Failed to extract ChatGPT account id from the Pi access token.")
    return token


def _login_pi_browser() -> dict:
    verifier, challenge = _pkce_pair()
    state = secrets.token_hex(16)
    url = urllib.parse.urlparse(PI_OAUTH_AUTHORIZE_URL)
    query = urllib.parse.urlencode(
        {
            "response_type": "code",
            "client_id": PI_OAUTH_CLIENT_ID,
            "redirect_uri": PI_OAUTH_REDIRECT_URI,
            "scope": PI_OAUTH_SCOPE,
            "code_challenge": challenge,
            "code_challenge_method": "S256",
            "state": state,
            "id_token_add_organizations": "true",
            "codex_cli_simplified_flow": "true",
            "originator": "pi",
        }
    )
    authorize = urllib.parse.urlunparse(url._replace(query=query))
    result: dict[str, str | None] = {"code": None, "error": None}

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format: str, *args: object) -> None:
            return

        def do_GET(self) -> None:
            parsed = urllib.parse.urlparse(self.path)
            params = urllib.parse.parse_qs(parsed.query)
            if parsed.path != "/auth/callback":
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b"Not found")
                return
            if params.get("state", [None])[0] != state:
                result["error"] = "OAuth state mismatch."
                body = b"State mismatch. You can close this window."
                self.send_response(400)
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            code = params.get("code", [None])[0]
            if not code:
                result["error"] = "Missing authorization code."
                body = b"Missing authorization code. You can close this window."
                self.send_response(400)
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            result["code"] = code
            body = b"OpenAI authentication completed. You can close this window."
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    try:
        httpd = HTTPServer(("127.0.0.1", PI_OAUTH_CALLBACK_PORT), Handler)
    except OSError as exc:
        die(f"Cannot bind 127.0.0.1:{PI_OAUTH_CALLBACK_PORT} for Pi login: {exc}")

    print(f"Open this URL in your browser:\n{authorize}", file=sys.stderr)
    try:
        webbrowser.open(authorize)
    except Exception:
        pass

    httpd.timeout = 1
    deadline = time.time() + PI_OAUTH_TIMEOUT_SECONDS
    try:
        while time.time() < deadline and not result["code"] and not result["error"]:
            httpd.handle_request()
    finally:
        httpd.server_close()

    if result["error"]:
        die(str(result["error"]))
    if not result["code"]:
        die("Pi login timed out waiting for the browser callback.")
    return _oauth_blob_from_token(_token_from_code(str(result["code"]), verifier, PI_OAUTH_REDIRECT_URI))


def _login_pi_device() -> dict:
    start = _http_json(PI_OAUTH_DEVICE_USER_CODE_URL, {"client_id": PI_OAUTH_CLIENT_ID}, "json")
    device_auth_id = start.get("device_auth_id")
    user_code = start.get("user_code")
    interval = start.get("interval")
    if isinstance(interval, str):
        interval = float(interval.strip())
    if not device_auth_id or not user_code or not isinstance(interval, (int, float)):
        die(f"Invalid OpenAI Codex device code response: {json.dumps(start)}")
    print(
        f"Open this URL in your browser:\n{PI_OAUTH_DEVICE_VERIFICATION_URI}\nEnter code: {user_code}",
        file=sys.stderr,
    )
    try:
        webbrowser.open(PI_OAUTH_DEVICE_VERIFICATION_URI)
    except Exception:
        pass

    deadline = time.time() + PI_OAUTH_TIMEOUT_SECONDS
    delay = max(float(interval), 1.0)
    while time.time() < deadline:
        time.sleep(delay)
        request = urllib.request.Request(
            PI_OAUTH_DEVICE_TOKEN_URL,
            data=json.dumps({"device_auth_id": device_auth_id, "user_code": user_code}).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                data = json.loads(response.read().decode())
        except urllib.error.HTTPError as exc:
            if exc.code in (403, 404):
                continue
            detail = exc.read().decode(errors="replace")
            try:
                parsed = json.loads(detail)
                error = parsed.get("error")
                code = error.get("code") if isinstance(error, dict) else error
            except Exception:
                code = None
            if code == "deviceauth_authorization_pending":
                continue
            if code == "slow_down":
                delay += 1
                continue
            die(f"OpenAI Codex device auth failed ({exc.code}): {detail or exc.reason}")
        except urllib.error.URLError as exc:
            die(f"OpenAI Codex device auth failed: {exc.reason}")
        else:
            authorization_code = data.get("authorization_code")
            code_verifier = data.get("code_verifier")
            if not authorization_code or not code_verifier:
                die(f"Invalid OpenAI Codex device auth token response: {json.dumps(data)}")
            return _oauth_blob_from_token(
                _token_from_code(authorization_code, code_verifier, PI_OAUTH_DEVICE_REDIRECT_URI)
            )
    die("Pi device login timed out.")
    return {}


def login_pi(pi_path: Path, device: bool) -> dict:
    blob = _login_pi_device() if device else _login_pi_browser()
    handle, tmp = tempfile.mkstemp(prefix=".pi-login.", suffix=".json", dir=str(pi_path.parent if pi_path.parent.exists() else Path(tempfile.gettempdir())))
    os.close(handle)
    tmp_path = Path(tmp)
    try:
        atomic_write_json(tmp_path, blob)
        return apply_pi_oauth(tmp_path, pi_path)
    finally:
        try:
            tmp_path.unlink()
        except OSError:
            pass


def agent_dir(accounts_home: Path, agent: str) -> Path:
    return accounts_home / agent


def saved_path(accounts_home: Path, agent: str | None, name: str) -> Path:
    return unified_saved_path(accounts_home, name)


def unified_saved_path(accounts_home: Path, name: str) -> Path:
    return accounts_home / f"{name}.json"


def iter_saved_unified(accounts_home: Path):
    seen: set[str] = set()
    if accounts_home.is_dir():
        for path in sorted(accounts_home.glob("*.json")):
            if not path.is_file() or path.name.endswith(".auth.json"):
                continue
            yield path.stem, path
            seen.add(path.stem)
    for agent in ("pi", "codex"):
        for name, path in iter_saved_legacy(accounts_home, agent):
            if name not in seen:
                yield name, path
                seen.add(name)


def iter_saved(accounts_home: Path, agent: str | None = None):
    yield from iter_saved_unified(accounts_home)


def iter_saved_legacy(accounts_home: Path, agent: str):
    directory = agent_dir(accounts_home, agent)
    if directory.is_dir():
        for path in sorted(directory.glob("*.json")):
            if path.is_file():
                yield path.stem, path

    # Old unscoped layout: accounts/<name>/codex.auth.json and pi.openai-codex.json
    if not accounts_home.is_dir():
        return
    for child in sorted(accounts_home.iterdir()):
        if not child.is_dir() or child.name in AGENTS or child.name.startswith("."):
            continue
        if agent == "codex":
            nested = child / "codex.auth.json"
            legacy = accounts_home / f"{child.name}.auth.json"
            if nested.is_file():
                yield child.name, nested
            elif legacy.is_file():
                yield child.name, legacy
        elif agent == "pi":
            nested = child / "pi.openai-codex.json"
            if nested.is_file():
                yield child.name, nested

    if agent == "codex":
        for child in sorted(accounts_home.glob("*.auth.json")):
            name = child.name.removesuffix(".auth.json")
            if name.endswith("-backup"):
                continue
            yield name, child


USAGE_URL_CHATGPT = "https://chatgpt.com/backend-api/wham/usage"
REFRESH_TOKEN_URL = f"{PI_OAUTH_AUTH_BASE}/oauth/token"


def _unwrap(value):
    if isinstance(value, dict) or value is None:
        return value
    return None


def _window_label(seconds) -> str:
    try:
        seconds = int(seconds)
    except (TypeError, ValueError):
        return "window"
    if seconds == 18000:
        return "5-hour"
    if seconds == 604800:
        return "7-day"
    if seconds >= 86400 and seconds % 86400 == 0:
        return f"{seconds // 86400}-day"
    if seconds >= 3600 and seconds % 3600 == 0:
        return f"{seconds // 3600}-hour"
    return f"{seconds}s"


def _format_duration(seconds) -> str:
    try:
        seconds = max(0, int(seconds))
    except (TypeError, ValueError):
        return "?"
    days, rem = divmod(seconds, 86400)
    hours, rem = divmod(rem, 3600)
    minutes, _ = divmod(rem, 60)
    parts = []
    if days:
        parts.append(f"{days}d")
    if hours:
        parts.append(f"{hours}h")
    if minutes or not parts:
        parts.append(f"{minutes}m")
    return " ".join(parts)


def _codex_tokens(data: dict) -> dict:
    tokens = data.get("tokens")
    return tokens if isinstance(tokens, dict) else {}


def _agent_secrets(agent: str, data: dict) -> tuple[str, str, str]:
    if looks_like_codex(data) or (agent == "codex" and not looks_like_pi(data)):
        tokens = _codex_tokens(data)
        return (
            str(tokens.get("access_token") or ""),
            str(tokens.get("refresh_token") or ""),
            str(tokens.get("account_id") or ""),
        )
    oauth = pi_oauth_from_data(data)
    return (
        str(oauth.get("access") or ""),
        str(oauth.get("refresh") or ""),
        str(oauth.get("accountId") or ""),
    )


def _access_needs_refresh(access: str, skew_seconds: int = 120) -> bool:
    exp = jwt_payload(access).get("exp")
    if not isinstance(exp, (int, float)):
        return False
    return float(exp) <= time.time() + skew_seconds


def _refresh_chatgpt_token(refresh_token: str, as_json: bool) -> dict:
    payload = {
        "client_id": PI_OAUTH_CLIENT_ID,
        "grant_type": "refresh_token",
        "refresh_token": refresh_token,
    }
    if as_json:
        body = json.dumps(payload).encode()
        headers = {"Content-Type": "application/json"}
    else:
        body = urllib.parse.urlencode(payload).encode()
        headers = {"Content-Type": "application/x-www-form-urlencoded"}
    request = urllib.request.Request(REFRESH_TOKEN_URL, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            data = json.loads(response.read().decode())
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")
        raise RuntimeError(f"token refresh failed ({exc.code}): {detail or exc.reason}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"token refresh failed: {exc.reason}") from exc
    if not isinstance(data, dict) or not data.get("access_token"):
        raise RuntimeError("token refresh response missing access_token")
    return data


def _apply_refreshed_tokens(agent: str, data: dict, refreshed: dict) -> dict:
    access = refreshed.get("access_token")
    new_refresh = refreshed.get("refresh_token")
    id_token = refreshed.get("id_token")
    expires_in = refreshed.get("expires_in")
    if agent == "codex":
        tokens = data.setdefault("tokens", {})
        if not isinstance(tokens, dict):
            tokens = {}
            data["tokens"] = tokens
        if access:
            tokens["access_token"] = access
        if new_refresh:
            tokens["refresh_token"] = new_refresh
        if id_token:
            tokens["id_token"] = id_token
        data["last_refresh"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        return data

    oauth = dict(pi_oauth_from_data(data))
    if access:
        oauth["access"] = access
        account_id = openai_auth_claims(access).get("chatgpt_account_id")
        if account_id:
            oauth["accountId"] = account_id
        if isinstance(expires_in, (int, float)):
            oauth["expires"] = int(time.time() * 1000) + int(expires_in) * 1000
        else:
            exp = jwt_payload(access).get("exp")
            if isinstance(exp, (int, float)):
                oauth["expires"] = int(exp * 1000)
    if new_refresh:
        oauth["refresh"] = new_refresh
    oauth["type"] = "oauth"
    if data.get("type") == "oauth":
        data.update(oauth)
    else:
        data["openai-codex"] = oauth
    return data


def _write_agent_file(agent: str, path: Path, data: dict, as_live: bool) -> None:
    if agent == "pi" and not as_live:
        atomic_write_json(path, pi_oauth_from_data(data))
        os.chmod(path, 0o600)
        return
    if agent == "pi" and as_live:
        live = {}
        if path.exists():
            live = load_json(path)
        live["openai-codex"] = pi_oauth_from_data(data)
        atomic_write_json(path, live)
        os.chmod(path, 0o600)
        return
    atomic_write_json(path, data)
    os.chmod(path, 0o600)


def _live_chatgpt_data(path: Path | None) -> dict | None:
    if path is None or not path.is_file():
        return None
    data = try_load_json(path)
    if data is None:
        return None
    if looks_like_codex(data) or looks_like_pi(data):
        ident = identity_from_any(data)
        if ident.get("account_id") and grant_refresh(data):
            return data
    return None


def _email_name(data: dict) -> str | None:
    email = identity_from_any(data).get("email")
    if isinstance(email, str) and "@" in email:
        return email.strip().lower()
    return None


def _plan_slug(plan: object) -> str:
    text = str(plan or "unknown").strip().lower()
    chars = [char for char in text if char.isalnum()]
    return "".join(chars) or "unknown"


def _account_heading(name: str, plan: object, email: str = "") -> str:
    slug = _plan_slug(plan)
    shown = name or email or "unknown"
    suffix = f".{slug}"
    if email and name in {email, f"{email}{suffix}"}:
        shown = email
    elif shown.endswith(suffix) and len(shown) > len(suffix):
        shown = shown[: -len(suffix)]
    return f"{shown}  [{slug}]"


def _slot_name(data: dict) -> str | None:
    email = _email_name(data)
    if not email:
        return None
    return f"{email}.{_plan_slug(identity_from_any(data).get('plan'))}"


def _resolve_saved_name(accounts_home: Path, name: str) -> str | None:
    if unified_saved_path(accounts_home, name).is_file():
        return name
    matches = []
    for saved_name, _path in iter_saved_unified(accounts_home):
        if saved_name == name or saved_name.startswith(f"{name}."):
            matches.append(saved_name)
    if len(matches) == 1:
        return matches[0]
    return None


def _preferred_saved_name(accounts_home: Path, data: dict | None) -> str | None:
    if data is None:
        return None
    account_id = grant_account_id(data)
    if not account_id:
        return None
    email = _email_name(data)
    wanted = _slot_name(data)
    names = []
    for name, path in iter_saved_unified(accounts_home):
        saved = try_load_json(path)
        if saved and grant_account_id(saved) == account_id:
            names.append(name)
    if wanted and wanted in names:
        return wanted
    if email and email in names:
        return email
    prefixed = [name for name in names if email and name.startswith(f"{email}.")]
    if len(prefixed) == 1:
        return prefixed[0]
    return names[0] if names else None


def migrate_store(accounts_home: Path) -> None:
    accounts_home.mkdir(parents=True, exist_ok=True)
    os.chmod(accounts_home, 0o700)
    names: dict[str, dict[str, Path]] = {}
    for agent in ("pi", "codex"):
        directory = agent_dir(accounts_home, agent)
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.json")):
            if path.is_file():
                names.setdefault(path.stem, {})[agent] = path

    legacy_root = accounts_home / ".legacy"
    for name, parts in names.items():
        dest = unified_saved_path(accounts_home, name)
        if not dest.is_file():
            source = parts.get("pi") or parts.get("codex")
            if source is None:
                continue
            data = try_load_json(source)
            if data is None:
                continue
            write_saved_grant(dest, data)
        for agent, path in parts.items():
            backup = legacy_root / agent / path.name
            backup.parent.mkdir(parents=True, exist_ok=True)
            os.chmod(backup.parent, 0o700)
            try:
                os.replace(path, backup)
            except OSError:
                pass
        for agent in ("pi", "codex"):
            directory = agent_dir(accounts_home, agent)
            if directory.is_dir():
                try:
                    next(directory.iterdir())
                except StopIteration:
                    try:
                        directory.rmdir()
                    except OSError:
                        pass
    _rename_saves_to_slot_names(accounts_home)


def _rename_saves_to_slot_names(accounts_home: Path) -> None:
    for name, path in list(iter_saved_unified(accounts_home)):
        data = try_load_json(path)
        if data is None:
            continue
        wanted = _slot_name(data)
        if not wanted or wanted == name:
            continue
        dest = unified_saved_path(accounts_home, wanted)
        if dest.is_file():
            continue
        try:
            os.replace(path, dest)
        except OSError:
            pass


def snapshot_live_file(path: Path, accounts_home: Path) -> str | None:
    data = _live_chatgpt_data(path)
    if data is None:
        return None
    name = _slot_name(data)
    if not name:
        return None
    dest = unified_saved_path(accounts_home, name)
    existing = try_load_json(dest) if dest.is_file() else None
    if existing is not None and grant_access_exp(existing) > grant_access_exp(data):
        return name
    write_saved_grant(dest, data)
    return name


def snapshot_lives(
    accounts_home: Path,
    codex_live: Path,
    pi_live: Path,
    opencode_live: Path | None = None,
) -> list[str]:
    saved = []
    for path in (pi_live, opencode_live, codex_live):
        if path is None:
            continue
        name = snapshot_live_file(path, accounts_home)
        if name and name not in saved:
            saved.append(name)
    return saved


def _same_account(left: dict, right: dict) -> bool:
    left_id = grant_account_id(left)
    right_id = grant_account_id(right)
    return bool(left_id) and left_id == right_id


def _live_label(data: dict) -> str:
    ident = identity_from_any(data)
    return str(ident.get("email") or ident.get("account_id") or "unknown")


def _pick_sync_winner(lives: dict[str, dict | None]) -> tuple[str, dict]:
    present = {name: data for name, data in lives.items() if data is not None}
    if not present:
        die("No ChatGPT Codex login in Pi, Codex, or OpenCode.")
    ids = {grant_account_id(data) for data in present.values()}
    if len(ids) > 1:
        parts = [f"{name}={_live_label(data)}" for name, data in present.items()]
        die(
            "Pi, Codex, and OpenCode are different ChatGPT accounts "
            f"({', '.join(parts)}). Use switch NAME to put the same login on all tools."
        )
    ranked = sorted(
        present.items(),
        key=lambda item: (
            grant_access_exp(item[1]),
            2 if item[0] == "pi" else 1 if item[0] == "opencode" else 0,
        ),
    )
    return ranked[-1]


def _update_matching_saves(accounts_home: Path, data: dict) -> list[str]:
    account_id = grant_account_id(data)
    updated = []
    wanted = _slot_name(data)
    if wanted:
        dest = unified_saved_path(accounts_home, wanted)
        write_saved_grant(dest, data)
        updated.append(wanted)
    if not account_id:
        return updated
    for name, path in iter_saved_unified(accounts_home):
        if name in updated:
            continue
        saved = try_load_json(path)
        if saved and grant_account_id(saved) == account_id:
            write_saved_grant(path, data)
            updated.append(name)
    return updated


def _maybe_write_live_if_same_account(path: Path | None, live_data: dict | None, grant: dict, writer) -> bool:
    if path is None:
        return False
    if live_data is None:
        writer(path, grant)
        return True
    if _same_account(live_data, grant):
        writer(path, grant)
        return True
    return False


def cmd_write_both(args: list[str]) -> None:
    source = "pi"
    source_file = None
    codex_live = None
    pi_live = None
    opencode_live = None
    force = False
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--from":
            i += 1
            source = args[i]
        elif arg == "--file":
            i += 1
            source_file = Path(args[i])
        elif arg == "--codex-live":
            i += 1
            codex_live = Path(args[i])
        elif arg == "--pi-live":
            i += 1
            pi_live = Path(args[i])
        elif arg == "--opencode-live":
            i += 1
            opencode_live = Path(args[i])
        elif arg == "--force":
            force = True
        else:
            die(f"unknown write-both option: {arg}")
        i += 1
    if source_file is not None:
        data = load_json(source_file)
    elif source == "pi":
        if pi_live is None:
            die("write-both --from pi requires --pi-live")
        data = load_json(pi_live)
    elif source == "codex":
        if codex_live is None:
            die("write-both --from codex requires --codex-live")
        data = load_json(codex_live)
    elif source == "opencode":
        if opencode_live is None:
            die("write-both --from opencode requires --opencode-live")
        data = load_json(opencode_live)
    else:
        die("write-both --from must be pi, codex, opencode, or used with --file")
    ident = identity_from_any(data)
    if not ident.get("account_id"):
        die("source has no ChatGPT account id")
    if force or source_file is not None:
        write_all_lives(data, codex_live, pi_live, opencode_live)
        print_identity(ident)
        return
    writers = {
        "pi": (pi_live, write_pi_live),
        "codex": (codex_live, write_codex_live),
        "opencode": (opencode_live, write_opencode_live),
    }
    wrote = False
    for name, (path, writer) in writers.items():
        live_data = _live_chatgpt_data(path)
        if name == source and path is not None:
            writer(path, data)
            wrote = True
            continue
        if _maybe_write_live_if_same_account(path, live_data, data, writer):
            wrote = True
    if not wrote:
        die("did not write any live file")
    print_identity(ident)


def cmd_sync(args: list[str]) -> None:
    parsed = _parse_common_paths(args)
    accounts_home = parsed["accounts_home"]
    lives = {
        "pi": _live_chatgpt_data(parsed["pi_live"]),
        "codex": _live_chatgpt_data(parsed["codex_live"]),
        "opencode": _live_chatgpt_data(parsed["opencode_live"]),
    }
    winner_name, winner = _pick_sync_winner(lives)
    present = {name: data for name, data in lives.items() if data is not None}
    already = bool(present) and len({grant_refresh(data) for data in present.values()}) == 1
    write_all_lives(winner, parsed["codex_live"], parsed["pi_live"], parsed["opencode_live"])
    updated = _update_matching_saves(accounts_home, winner)
    ident = identity_from_any(winner)
    label = ident.get("email") or ident.get("account_id")
    if already and len(present) == 3:
        print(f"Already in sync ({label}).")
        return
    saves = ", ".join(updated) if updated else "none"
    print(f"Synced from {winner_name} ({label}) to Pi, Codex, and OpenCode. Updated saves: {saves}.")


def cmd_refresh(args: list[str]) -> None:
    parsed = _parse_common_paths(args)
    accounts_home = parsed["accounts_home"]
    codex_live = parsed["codex_live"]
    pi_live = parsed["pi_live"]
    name = parsed.get("name")
    if name:
        resolved = _resolve_saved_name(accounts_home, name)
        if not resolved:
            die(f"Unknown account '{name}'.")
        name = resolved
        path = unified_saved_path(accounts_home, name)
        data = load_json(path)
        source = "saved"
    else:
        pi_data = _live_chatgpt_data(pi_live)
        opencode_data = _live_chatgpt_data(parsed["opencode_live"])
        codex_data = _live_chatgpt_data(codex_live)
        if pi_data is not None:
            data = pi_data
            source = "pi"
        elif opencode_data is not None:
            data = opencode_data
            source = "opencode"
        elif codex_data is not None:
            data = codex_data
            source = "codex"
        else:
            die("No ChatGPT Codex login in Pi, Codex, or OpenCode.")
    refresh = grant_refresh(data)
    if not refresh:
        die("selected login has no refresh token")
    try:
        refreshed = _refresh_chatgpt_token(refresh, as_json=False)
    except Exception as exc:
        die(str(exc))
    if looks_like_codex(data):
        data = _apply_refreshed_tokens("codex", dict(data), refreshed)
    else:
        data = _apply_refreshed_tokens("pi", dict(data), refreshed)
    pi_data = _live_chatgpt_data(pi_live)
    codex_data = _live_chatgpt_data(codex_live)
    opencode_data = _live_chatgpt_data(parsed["opencode_live"])
    wrote_pi = _maybe_write_live_if_same_account(pi_live, pi_data, data, write_pi_live)
    wrote_codex = _maybe_write_live_if_same_account(codex_live, codex_data, data, write_codex_live)
    wrote_opencode = _maybe_write_live_if_same_account(
        parsed["opencode_live"], opencode_data, data, write_opencode_live
    )
    if source == "pi":
        write_pi_live(pi_live, data)
        wrote_pi = True
    elif source == "codex":
        write_codex_live(codex_live, data)
        wrote_codex = True
    elif source == "opencode":
        write_opencode_live(parsed["opencode_live"], data)
        wrote_opencode = True
    updated = _update_matching_saves(accounts_home, data)
    ident = identity_from_any(data)
    targets = []
    if wrote_pi:
        targets.append("pi")
    if wrote_codex:
        targets.append("codex")
    if wrote_opencode:
        targets.append("opencode")
    if updated:
        targets.extend(updated)
    print(
        f"Refreshed {ident.get('email') or ident.get('account_id')} "
        f"({', '.join(targets) or 'saved only'})."
    )


def cmd_save_live(args: list[str]) -> None:
    parsed = _parse_common_paths(args)
    accounts_home = parsed["accounts_home"]
    name = parsed.get("name")
    source = parsed.get("source") or "pi"
    if source == "codex":
        data = _live_chatgpt_data(parsed["codex_live"])
        if data is None:
            die(f"No ChatGPT Codex login in {parsed['codex_live']}")
    elif source == "opencode":
        data = _live_chatgpt_data(parsed["opencode_live"])
        if data is None:
            die(f"No ChatGPT Codex login in {parsed['opencode_live']}")
    elif source == "both":
        saved = snapshot_lives(
            accounts_home, parsed["codex_live"], parsed["pi_live"], parsed["opencode_live"]
        )
        if not saved:
            die("No ChatGPT Codex login in Pi, Codex, or OpenCode.")
        print("Saved " + ", ".join(saved) + ".")
        return
    else:
        data = _live_chatgpt_data(parsed["pi_live"])
        if data is None:
            data = _live_chatgpt_data(parsed["opencode_live"])
            source = "opencode"
        if data is None:
            data = _live_chatgpt_data(parsed["codex_live"])
            source = "codex"
        if data is None:
            die("No ChatGPT Codex login in Pi, Codex, or OpenCode.")
    if not name:
        name = _slot_name(data)
        if not name:
            die("No email in the token. Pass -n/--name.")
    dest = unified_saved_path(accounts_home, name)
    write_saved_grant(dest, data)
    ident = identity_from_any(data)
    print(f"Saved '{name}' ({ident.get('plan') or 'unknown'} {ident.get('email') or ident.get('account_id')}).")


def cmd_switch_grant(args: list[str]) -> None:
    parsed = _parse_common_paths(args)
    accounts_home = parsed["accounts_home"]
    name = parsed.get("name")
    if not name:
        die("switch requires a saved account name")
    resolved = _resolve_saved_name(accounts_home, name)
    if not resolved:
        die(f"Unknown account '{name}'. Save it first with 'codex-account save'.")
    name = resolved
    path = unified_saved_path(accounts_home, name)
    snapshot_lives(accounts_home, parsed["codex_live"], parsed["pi_live"], parsed["opencode_live"])
    data = load_json(path)
    ident = identity_from_any(data)
    if not ident.get("account_id") or not grant_refresh(data):
        die(f"saved account '{name}' is not a ChatGPT Codex login")
    write_all_lives(data, parsed["codex_live"], parsed["pi_live"], parsed["opencode_live"])
    print(f"Switched Pi, Codex, and OpenCode to '{name}' ({ident.get('plan') or 'unknown'} {ident.get('email') or ident.get('account_id')}).")
    print("Restart Pi/Codex/OpenCode if they are already running.")


def cmd_list_accounts(args: list[str]) -> None:
    parsed = _parse_common_paths(args)
    accounts_home = parsed["accounts_home"]
    pi_data = _live_chatgpt_data(parsed["pi_live"])
    codex_data = _live_chatgpt_data(parsed["codex_live"])
    pi_name = _preferred_saved_name(accounts_home, pi_data)
    codex_name = _preferred_saved_name(accounts_home, codex_data)
    rows = []
    for name, path in iter_saved_unified(accounts_home):
        data = try_load_json(path)
        if data is None:
            continue
        ident = identity_from_any(data)
        marks = []
        if name == pi_name:
            marks.append("pi")
        if name == codex_name:
            marks.append("codex")
        rows.append((name, ident.get("plan") or "unknown", ident.get("email") or "", marks))
    if not rows:
        print("(none)")
        return
    for name, plan, email, marks in rows:
        prefix = "*" if "pi" in marks else ("c" if "codex" in marks else " ")
        print(f"{prefix} {_account_heading(name, plan, email)}")


def cmd_current(args: list[str]) -> None:
    parsed = _parse_common_paths(args)
    lives = {
        "pi": (_live_chatgpt_data(parsed["pi_live"]), parsed["pi_live"]),
        "codex": (_live_chatgpt_data(parsed["codex_live"]), parsed["codex_live"]),
        "opencode": (_live_chatgpt_data(parsed["opencode_live"]), parsed["opencode_live"]),
    }

    def describe(label: str, data: dict | None, path: Path) -> None:
        if data is None:
            if path.is_file():
                print(f"{label:<8} no ChatGPT Codex login")
            else:
                print(f"{label:<8} no auth.json")
            return
        ident = identity_from_any(data)
        name = _preferred_saved_name(parsed["accounts_home"], data)
        email = ident.get("email") or ""
        plan = ident.get("plan") or "unknown"
        shown = name or "unsaved"
        extra = f"{plan} {email}".strip()
        print(f"{label:<8} {shown} ({extra})")

    for label, (data, path) in lives.items():
        describe(label, data, path)
    present = [data for data, _path in lives.values() if data is not None]
    if len(present) < 2:
        print("shared no")
        return
    ids = {grant_account_id(data) for data in present}
    if len(ids) > 1:
        print("shared no (different accounts; switch NAME to share)")
        return
    refreshes = {grant_refresh(data) for data in present}
    if len(refreshes) == 1:
        print("shared yes")
        return
    print("shared same account, tokens drifted (run sync)")


def _parse_common_paths(args: list[str]) -> dict:
    out: dict = {
        "accounts_home": None,
        "codex_live": None,
        "pi_live": None,
        "opencode_live": None,
        "name": None,
        "source": None,
        "json": False,
    }
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--accounts-home":
            i += 1
            out["accounts_home"] = Path(args[i])
        elif arg == "--codex-live":
            i += 1
            out["codex_live"] = Path(args[i])
        elif arg == "--pi-live":
            i += 1
            out["pi_live"] = Path(args[i])
        elif arg == "--opencode-live":
            i += 1
            out["opencode_live"] = Path(args[i])
        elif arg == "--name":
            i += 1
            out["name"] = args[i]
        elif arg == "--from":
            i += 1
            out["source"] = args[i]
        elif arg == "--json":
            out["json"] = True
        else:
            die(f"unknown option: {arg}")
        i += 1
    if out["accounts_home"] is None:
        die("missing --accounts-home")
    if out["codex_live"] is None:
        die("missing --codex-live")
    if out["pi_live"] is None:
        die("missing --pi-live")
    if out["opencode_live"] is None:
        die("missing --opencode-live")
    return out


def _get_wham_usage(access: str, account_id: str) -> tuple[int, dict | str]:
    headers = {
        "Authorization": f"Bearer {access}",
        "User-Agent": "codex-cli",
    }
    if account_id:
        headers["ChatGPT-Account-Id"] = account_id
    request = urllib.request.Request(USAGE_URL_CHATGPT, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.loads(response.read().decode())
            return response.status, payload if isinstance(payload, dict) else {"raw": payload}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")
        try:
            parsed = json.loads(detail)
        except Exception:
            parsed = detail or exc.reason
        return exc.code, parsed
    except urllib.error.URLError as exc:
        return 0, str(exc.reason)


def _remaining_percent(used) -> int | None:
    try:
        used = int(used)
    except (TypeError, ValueError):
        return None
    return max(0, min(100, 100 - used))


def _parse_window(snapshot: dict | None) -> dict | None:
    snapshot = _unwrap(snapshot)
    if not isinstance(snapshot, dict):
        return None
    used = snapshot.get("used_percent")
    return {
        "label": _window_label(snapshot.get("limit_window_seconds")),
        "used_percent": used,
        "remaining_percent": _remaining_percent(used),
        "limit_window_seconds": snapshot.get("limit_window_seconds"),
        "reset_after_seconds": snapshot.get("reset_after_seconds"),
        "reset_at": snapshot.get("reset_at"),
    }


def _parse_rate_limit_details(details) -> tuple[list[dict], bool | None, bool | None]:
    details = _unwrap(details)
    if not isinstance(details, dict):
        return [], None, None
    windows = []
    for key in ("primary_window", "secondary_window"):
        parsed = _parse_window(details.get(key))
        if parsed:
            windows.append(parsed)
    return windows, details.get("allowed"), details.get("limit_reached")


def _normalize_usage_payload(payload: dict) -> dict:
    windows, allowed, limit_reached = _parse_rate_limit_details(payload.get("rate_limit"))
    additional = []
    extra = payload.get("additional_rate_limits")
    if isinstance(extra, list):
        for item in extra:
            if not isinstance(item, dict):
                continue
            extra_windows, extra_allowed, extra_reached = _parse_rate_limit_details(item.get("rate_limit"))
            additional.append(
                {
                    "limit_name": item.get("limit_name") or "",
                    "metered_feature": item.get("metered_feature") or "",
                    "allowed": extra_allowed,
                    "limit_reached": extra_reached,
                    "windows": extra_windows,
                }
            )
    credits = _unwrap(payload.get("credits")) or {}
    spend = _unwrap(payload.get("spend_control")) or {}
    return {
        "plan_type": payload.get("plan_type") or "unknown",
        "allowed": allowed,
        "limit_reached": limit_reached,
        "windows": windows,
        "additional": additional,
        "credits": {
            "has_credits": bool(credits.get("has_credits")) if isinstance(credits, dict) else False,
            "unlimited": bool(credits.get("unlimited")) if isinstance(credits, dict) else False,
            "balance": credits.get("balance") if isinstance(credits, dict) else None,
        },
        "spend_control": spend if isinstance(spend, dict) else {},
    }


def _apply_agent(data: dict) -> str:
    return "codex" if looks_like_codex(data) else "pi"


def _ensure_fresh_tokens(agent: str, data: dict) -> tuple[dict, bool]:
    apply_agent = _apply_agent(data)
    access, refresh, _account_id = _agent_secrets(apply_agent, data)
    if not refresh:
        raise RuntimeError(f"{agent} auth has no refresh token")
    if access and not _access_needs_refresh(access):
        return data, False
    refreshed = _refresh_chatgpt_token(refresh, as_json=False)
    return _apply_refreshed_tokens(apply_agent, data, refreshed), True


def _persist_grant(path: Path, data: dict, live_paths: dict[str, Path]) -> None:
    resolved = path.resolve()
    pi_live = live_paths.get("pi")
    codex_live = live_paths.get("codex")
    opencode_live = live_paths.get("opencode")
    if pi_live is not None and pi_live.is_file() and pi_live.resolve() == resolved:
        write_pi_live(path, data)
        return
    if codex_live is not None and codex_live.is_file() and codex_live.resolve() == resolved:
        write_codex_live(path, data)
        return
    if opencode_live is not None and opencode_live.is_file() and opencode_live.resolve() == resolved:
        write_opencode_live(path, data)
        return
    write_saved_grant(path, data)


def _fetch_usage_for_file(
    agent: str,
    path: Path,
    name: str,
    live_paths: dict[str, Path],
    accounts_home: Path | None,
) -> dict:
    result = {"ok": False, "agent": agent, "name": name, "path": str(path)}
    data = try_load_json(path)
    if data is None:
        result["error"] = f"cannot read {path}"
        return result

    identity = identity_from_any(data)
    result["email"] = identity.get("email") or ""
    result["plan"] = identity.get("plan") or "unknown"
    result["account_id"] = identity.get("account_id") or ""
    result["refreshed"] = False

    try:
        data, refreshed = _ensure_fresh_tokens(agent, data)
        result["refreshed"] = refreshed
        if refreshed:
            _persist_grant(path, data, live_paths)
            if accounts_home:
                _sync_related_token_copies(
                    path, data, live_paths, accounts_home, result["account_id"]
                )
    except Exception as exc:
        result["error"] = f"refresh failed: {exc}"
        return result

    access, _refresh, account_id = _agent_secrets(_apply_agent(data), data)
    account_id = account_id or result["account_id"]
    status, payload = _get_wham_usage(access, account_id)
    if status == 401:
        try:
            apply_agent = _apply_agent(data)
            _access, refresh, _account = _agent_secrets(apply_agent, data)
            refreshed = _refresh_chatgpt_token(refresh, as_json=False)
            data = _apply_refreshed_tokens(apply_agent, data, refreshed)
            result["refreshed"] = True
            _persist_grant(path, data, live_paths)
            if accounts_home:
                _sync_related_token_copies(
                    path, data, live_paths, accounts_home, result["account_id"]
                )
            access, _refresh, account_id = _agent_secrets(apply_agent, data)
            status, payload = _get_wham_usage(access, account_id or result["account_id"])
        except Exception as exc:
            result["error"] = f"usage unauthorized, refresh retry failed: {exc}"
            return result

    if status != 200 or not isinstance(payload, dict):
        result["error"] = f"usage HTTP {status}: {payload if isinstance(payload, str) else payload.get('error') or payload.get('message') or 'request failed'}"
        return result

    usage = _normalize_usage_payload(payload)
    identity = identity_from_saved(agent, data)
    result.update(
        {
            "ok": True,
            "email": identity.get("email") or result["email"],
            "plan": identity.get("plan") or result["plan"],
            "account_id": identity.get("account_id") or account_id,
            **usage,
        }
    )
    return result


def _sync_related_token_copies(
    source_path: Path,
    data: dict,
    live_paths: dict[str, Path],
    accounts_home: Path,
    account_id: str,
) -> None:
    if not account_id:
        return
    source_resolved = source_path.resolve()
    for agent, live_path in live_paths.items():
        if live_path is None or not live_path.is_file():
            continue
        if live_path.resolve() == source_resolved:
            continue
        live = try_load_json(live_path)
        if live and grant_account_id(live) == account_id:
            if agent == "pi":
                write_pi_live(live_path, data)
            elif agent == "opencode":
                write_opencode_live(live_path, data)
            else:
                write_codex_live(live_path, data)
    _update_matching_saves(accounts_home, data)


def _print_usage_human(rows: list[dict]) -> None:
    if not rows:
        print("No Codex usage targets.")
        return
    for row in rows:
        name = row.get("name") or "unsaved"
        plan = row.get("plan") or row.get("plan_type") or "unknown"
        email = row.get("email") or ""
        header = f"{'*' if row.get('live') else ' '} {_account_heading(name, plan, email)}"
        print(header)
        if not row.get("ok"):
            print(f"  error  {row.get('error') or 'failed'}")
            print()
            continue
        windows = row.get("windows") or []
        if not windows:
            print("  (no rate-limit windows)")
        for window in windows:
            remaining = window.get("remaining_percent")
            if remaining is None:
                remaining = _remaining_percent(window.get("used_percent"))
            remain_text = f"{remaining}% remaining" if remaining is not None else "unknown"
            reset = _format_duration(window.get("reset_after_seconds"))
            print(f"  {str(window.get('label') or 'window'):<8} {remain_text:<16} resets in {reset}")
        credits = row.get("credits") or {}
        balance = credits.get("balance")
        if credits.get("unlimited"):
            print("  credits  unlimited")
        elif credits.get("has_credits") and balance not in (None, "", 0, "0"):
            print(f"  credits  {balance}")
        for extra in row.get("additional") or []:
            label = extra.get("limit_name") or extra.get("metered_feature") or "extra"
            extra_windows = extra.get("windows") or []
            if extra_windows:
                for window in extra_windows:
                    remaining = window.get("remaining_percent")
                    if remaining is None:
                        remaining = _remaining_percent(window.get("used_percent"))
                    remain_text = f"{remaining}% remaining" if remaining is not None else "unknown"
                    reset = _format_duration(window.get("reset_after_seconds"))
                    print(f"  {label:<8} {remain_text:<16} resets in {reset}")
            elif extra.get("limit_reached"):
                print(f"  {label:<8} limit reached")
        print()


def _source_identity(agent: str, path: Path, name: str, is_live: bool) -> dict | None:
    data = try_load_json(path)
    if data is None:
        return None
    ident = identity_from_saved(agent, data)
    email = (ident.get("email") or "").strip().lower()
    slot = _slot_name(data) or ""
    return {
        "agent": agent,
        "name": name,
        "path": path,
        "is_live": is_live,
        "account_id": ident.get("account_id") or "",
        "email": email,
        "plan": ident.get("plan") or "unknown",
        "slot": slot,
    }


def _usage_group_key(source: dict) -> tuple[str, str]:
    email = source.get("email") or ""
    name = source.get("name") or ""
    if email:
        return ("email", email)
    if name and name != "live":
        return ("name", name)
    if source.get("account_id"):
        return ("id", source["account_id"])
    return ("path", f"{source['agent']}:{source['path']}")


def _pick_usage_source(sources: list[dict]) -> dict:
    def rank(source: dict) -> tuple[int, int, str]:
        return (
            0 if source.get("is_live") else 1,
            0 if source.get("agent") == "pi" else 1,
            source.get("name") or "",
        )

    return sorted(sources, key=rank)[0]


def _collect_usage_targets(
    agent_filter: str | None,
    name: str | None,
    want_all: bool,
    accounts_home: Path,
    live_paths: dict[str, Path],
) -> list[dict]:
    if name:
        path = unified_saved_path(accounts_home, name)
        if not path.is_file():
            die(f"Unknown account '{name}'.")
        source = _source_identity("saved", path, name, is_live=False)
        if source is None:
            die(f"cannot read {path}")
        return [
            {
                "source": source,
                "display": source.get("slot") or source.get("email") or name,
                "agents": ["saved"],
                "live": False,
                "emails": [source.get("email") or name],
            }
        ]

    sources: list[dict] = []
    seen_paths: set[str] = set()
    agents = (agent_filter,) if agent_filter else AGENTS
    for agent in agents:
        live = live_paths.get(agent)
        if live and live.is_file():
            live_source = _source_identity(agent, live, "live", is_live=True)
            if live_source is not None:
                sources.append(live_source)
                seen_paths.add(str(live.resolve()))
    for saved_name, path in iter_saved_unified(accounts_home):
        resolved = str(path.resolve())
        if resolved in seen_paths:
            continue
        saved_source = _source_identity("saved", path, saved_name, is_live=False)
        if saved_source is not None:
            sources.append(saved_source)
            seen_paths.add(resolved)

    groups: dict[tuple[str, str], list[dict]] = {}
    for source in sources:
        groups.setdefault(_usage_group_key(source), []).append(source)

    targets = []
    for grouped in groups.values():
        chosen = _pick_usage_source(grouped)
        agents_present = []
        for source in grouped:
            if source["agent"] not in agents_present:
                agents_present.append(source["agent"])
        agents_present.sort()
        live = any(source.get("is_live") for source in grouped)
        display = chosen.get("slot") or chosen.get("email") or chosen.get("name") or "unknown"
        if display == "live":
            display = chosen.get("slot") or chosen.get("email") or "unsaved"
        targets.append(
            {
                "source": chosen,
                "display": display,
                "agents": agents_present,
                "live": live,
                "emails": [display],
            }
        )

    targets.sort(key=lambda item: (not item["live"], item["display"]))
    if not targets:
        die("No saved or live Codex accounts found.")
    return targets


def usage_report(args: list[str]) -> None:
    as_json = False
    want_all = False
    agent = None
    name = None
    accounts_home = None
    live_paths: dict[str, Path] = {}
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--json":
            as_json = True
        elif arg == "--all":
            want_all = True
        elif arg == "--agent":
            i += 1
            if i >= len(args):
                die("missing value for --agent")
            agent = args[i]
            if agent not in AGENTS:
                die(f"Unknown agent '{agent}'. Use 'codex', 'pi', or 'opencode'.")
        elif arg == "--name":
            i += 1
            if i >= len(args):
                die("missing value for --name")
            name = args[i]
        elif arg == "--accounts-home":
            i += 1
            accounts_home = Path(args[i])
        elif arg == "--codex-live":
            i += 1
            live_paths["codex"] = Path(args[i])
        elif arg == "--pi-live":
            i += 1
            live_paths["pi"] = Path(args[i])
        elif arg == "--opencode-live":
            i += 1
            live_paths["opencode"] = Path(args[i])
        else:
            die(f"unknown usage-report option: {arg}")
        i += 1

    if accounts_home is None:
        die("usage-report requires --accounts-home")
    if name and want_all:
        die("use either --all or --name, not both")
    if name:
        resolved = _resolve_saved_name(accounts_home, name)
        if not resolved:
            die(f"Unknown account '{name}'.")
        name = resolved

    targets = _collect_usage_targets(agent, name, want_all, accounts_home, live_paths)
    rows = []
    usage_by_account_id: dict[str, dict] = {}
    cached_fields = (
        "ok",
        "windows",
        "credits",
        "additional",
        "plan_type",
        "allowed",
        "limit_reached",
        "spend_control",
        "error",
    )
    for target in targets:
        source = target["source"]
        account_id = source.get("account_id") or ""
        cached = usage_by_account_id.get(account_id) if account_id else None
        if cached:
            row = {
                "agent": source["agent"],
                "name": target["display"],
                "email": source.get("email") or target["display"],
                "plan": source.get("plan") or cached.get("plan_type") or "unknown",
                "account_id": account_id,
                "refreshed": False,
                "path": str(source["path"]),
                **{field: cached[field] for field in cached_fields if field in cached},
            }
        else:
            row = _fetch_usage_for_file(
                source["agent"],
                source["path"],
                target["display"],
                live_paths,
                accounts_home,
            )
            if account_id and row.get("ok"):
                usage_by_account_id[account_id] = {field: row.get(field) for field in cached_fields}
        row["agents"] = target["agents"]
        row["live"] = target["live"]
        row["name"] = target["display"]
        if target["emails"] and not row.get("email"):
            row["email"] = target["emails"][0]
        rows.append(row)
    if as_json:
        print(json.dumps(rows, indent=2))
    else:
        _print_usage_human(rows)
    if rows and not any(row.get("ok") for row in rows):
        raise SystemExit(1)


def match_live(agent: str, auth_path: Path, accounts_home: Path) -> None:
    if not auth_path.is_file():
        return
    live_data = try_load_json(auth_path)
    if live_data is None:
        return
    live_id = identity_from_any(live_data).get("account_id")
    if not live_id:
        return
    name = _preferred_saved_name(accounts_home, live_data)
    if name:
        print(name)


def main(argv: list[str]) -> None:
    if not argv:
        die("missing python helper command")
    command = argv[0]
    args = argv[1:]

    if command == "identity":
        if len(args) < 2 or not args[1]:
            die("identity requires a JSON file path")
        kind = args[0]
        path = Path(args[1])
        data = load_json(path)
        identity = identity_from_saved(kind, data)
        print_identity(identity)
        return

    if command == "require-codex":
        require_chatgpt_codex(load_json(Path(args[0])), args[0])
        return

    if command == "require-pi":
        require_pi_oauth(load_json(Path(args[0])), args[0])
        return

    if command == "extract-pi-oauth":
        identity = extract_pi_oauth(Path(args[0]), Path(args[1]))
        print_identity(identity)
        return

    if command == "apply-pi-oauth":
        identity = apply_pi_oauth(Path(args[0]), Path(args[1]))
        print_identity(identity)
        return

    if command == "match":
        match_live(args[0], Path(args[1]), Path(args[2]))
        return

    if command == "login-pi":
        device = False
        paths = []
        for arg in args:
            if arg in ("--device", "--device-auth"):
                device = True
            else:
                paths.append(arg)
        if not paths:
            die("login-pi requires the Pi auth.json path")
        identity = login_pi(Path(paths[0]), device=device)
        print_identity(identity)
        return

    if command == "usage-report":
        usage_report(args)
        return

    if command == "migrate-store":
        if not args:
            die("migrate-store requires the accounts home path")
        migrate_store(Path(args[0]))
        return

    if command == "write-both":
        cmd_write_both(args)
        return

    if command == "sync":
        cmd_sync(args)
        return

    if command == "refresh":
        cmd_refresh(args)
        return

    if command == "save-live":
        cmd_save_live(args)
        return

    if command == "switch-grant":
        cmd_switch_grant(args)
        return

    if command == "list-accounts":
        cmd_list_accounts(args)
        return

    if command == "resolve-name":
        parsed = _parse_common_paths(args)
        name = parsed.get("name")
        if not name:
            die("resolve-name requires --name")
        resolved = _resolve_saved_name(parsed["accounts_home"], name)
        if not resolved:
            die(f"Unknown account '{name}'.")
        print(resolved)
        return

    if command == "current-grants":
        cmd_current(args)
        return

    if command == "snapshot-lives":
        parsed = _parse_common_paths(args)
        saved = snapshot_lives(
            parsed["accounts_home"], parsed["codex_live"], parsed["pi_live"], parsed["opencode_live"]
        )
        if saved:
            print("Updated saved tokens for " + ", ".join(saved) + ".")
        return

    die(f"unknown python helper command: {command}")


if __name__ == "__main__":
    main(sys.argv[1:])
