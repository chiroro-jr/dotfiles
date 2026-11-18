# History and versions

## Why / when / regressions

Read history before speculating: `git log -- <path>`, `git log -S <symbol>`, `git blame -L`, `git show <sha>`. Cite the commit and any PR/issue alongside the source permalink.

`gh search` tokenizes terms (`ui-sdk` matches `ui` and `sdk`), so quote the phrase and confirm each hit by opening it:

```bash
gh search issues '"exact phrase"' --repo owner/repo --match title,body,comments
gh pr view <n> --repo owner/repo --comments
```

## A specific version

Answer from that version, not `main`, and cite its SHA.

- Find it first: older majors usually live on a branch (`git branch -r`, e.g. `origin/v3`) or per-package tags; check `package.json` `version` to confirm what a ref holds.
- Whole-version research: `repo.sh <repo> <branch-tag-or-sha>` gives that ref its own folder; the default checkout is untouched.
- A few files: `git show <tag>:path` with no checkout; cite `git rev-parse <tag>^{commit}`.
- Monorepos tag per package (`@effect/platform@0.97.3`). Latest tag: `git tag --list '@scope/pkg@*' | sort -V | tail -1`.
- Files moved between major versions: when a path is missing on `main`, look for it at the last tag of the older major.

## Refresh everything

`repo.sh` already fetches what it opens. Only when the user asks to update the whole cache: `<skill-dir>/scripts/update-repos.sh` (see `--help`).
