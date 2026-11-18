---
name: sourcerer
description: Answer library, framework, and repo questions from the source code, with permalinks. Use for how a dependency works or is used, where behavior lives, why something changed, or comparing open-source repos.
---

# Sourcerer

Follow every claim back to the source that owns it: the code, its tests, its own docs. Secondary write-ups only point the way.

## Open the repo

```bash
REPO="$(<skill-dir>/scripts/repo.sh <repo> [ref])"
```

- `<skill-dir>` is the "Base directory" shown when this skill loads. Call by absolute path; no `cd`.
- `<repo>`: any GitHub/GitLab URL (deep links fine), `git@host:owner/repo.git`, or `owner/repo` for GitHub.
- `[ref]`: branch, tag, or SHA, checked out in its own folder (`<repo>@<ref>`), so parallel agents on other refs never move your files. Omitted → remote default branch.
- Run it before every first read of a repo in a session: the cache (`/var/tmp/sourcerer`, `$SOURCERER_REPOS` overrides) is pruned by the OS, and `repo.sh` repairs, fetches, and checks out in one go. Checkouts are read-only; it force-resets them.

**Finding the repo** from a package name: check the cache (`ls /var/tmp/sourcerer/*/*`), then package metadata (`npm view <pkg> repository.url`), then one web lookup. Docs sites often live in a separate repo: `gh repo list <org>`, look for `website`/`docs`. Accept only an official match (package metadata, or the project's own docs linking it). No match after that → fall back (below).

## Research

1. **Locate.** Grep exact symbols, option names, error strings. In monorepos, find the owning package before reading.
2. **Read.** Usage questions: docs, examples, and tests first. Implementation questions: the code path, then tests that pin it. Source beats docs; mention any conflict.
3. **History** (why/when/regressions) or **any version besides the default branch** (an older major, release, tag, or date): read [history.md](history.md).
4. **Fall back** to the project's official docs site, then web search, only when no usable repo exists or source can't answer. Label the answer docs-backed.

## Cite

Every non-obvious claim gets a permalink pinned to the full SHA with exact lines:

```txt
https://github.com/<owner>/<repo>/blob/<git rev-parse HEAD>/path/file.ts#L10-L30
```

Lead with the direct answer, then evidence. Separate what you saw from what you inferred.
