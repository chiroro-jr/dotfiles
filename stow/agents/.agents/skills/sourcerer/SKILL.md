---
name: sourcerer
description: Source-first research for libraries, frameworks, packages, and GitHub repositories. Use when answering questions about how a dependency works, how to use an API, where behavior is implemented, why something changed, or when comparing open-source repos. Searches persistent local clones in `~/.sourcerer/repos`, clones missing GitHub repos there, answers from source/docs/tests/examples with immutable GitHub permalinks, uses git history/PRs/issues for context, and falls back to ctx7/find-docs only when no usable reference repo exists.
---

# Sourcerer

Research libraries from source code first. Prefer local cloned repositories over web summaries. Use docs only as supporting evidence unless no source repository is available.

## Repository Cache

Use this persistent cache root:

```txt
~/.sourcerer/repos
```

Store repositories by host, owner, and repo to avoid name collisions:

```txt
~/.sourcerer/repos/github.com/TanStack/query
~/.sourcerer/repos/github.com/drizzle-team/drizzle-orm
~/.sourcerer/repos/github.com/honojs/hono
```

For non-GitHub hosts, keep the same shape:

```txt
~/.sourcerer/repos/gitlab.com/owner/repo
~/.sourcerer/repos/bitbucket.org/owner/repo
```

## Research Priority

Use this order unless the user asks otherwise:

1. Existing local clone in `~/.sourcerer/repos`.
2. Clone the user-provided repository URL into `~/.sourcerer/repos`.
3. Search repository docs, examples, tests, and source locally.
4. Use git history, blame, GitHub PRs, and issues when the question is about changes or rationale.
5. Fall back to ctx7/find-docs when no usable source repository exists or when source is insufficient for API usage.
6. Use web search only for current ecosystem context, release announcements, blog posts, or when repo/docs are not enough.

## Step 1: Classify the Request

Classify before searching so you choose the right evidence:

| Type | Triggers | Primary evidence |
| --- | --- | --- |
| Usage | "How do I use X?", API examples, config questions | docs, examples, tests, then source |
| Implementation | "How does X work?", internals, behavior | source, tests, exact symbols |
| History | "Why did this change?", regressions, when introduced | git log, git blame, PRs/issues |
| Comparison | "Compare X and Y" | source/docs from each repo |
| Comprehensive | broad or ambiguous deep dives | source + docs + tests + history + fallback docs |
| Video/tutorial | user provides YouTube/local video | video transcript/frames using the user question as prompt |

## Step 2: Resolve the Repository

If the user gives a GitHub URL:

1. Derive the cache path: `~/.sourcerer/repos/github.com/<owner>/<repo>`.
2. If it exists, reuse it.
3. If it does not exist, clone it there.
4. If the user mentions a branch, tag, or version, check out that ref before researching.

If the user gives a package/library name but no URL:

1. Search existing local clones first.
2. If there is one obvious match, use it.
3. If multiple repos could match, ask one brief clarifying question.
4. If no local repo exists, make one bounded repo-discovery attempt before falling back to docs.

Missing repo discovery:

1. Try package metadata first when practical, for example `npm view <pkg> repository.url homepage`.
2. If metadata is unavailable or inconclusive, use librarian for one web/current lookup to find the canonical source repo.
3. Accept only high-confidence matches:
   - official package metadata,
   - official docs/homepage linking to the repo,
   - clearly owned GitHub/GitLab/Codeberg org and package repo.
4. If found, clone into `~/.sourcerer/repos/<host>/<owner>/<repo>` and continue source-first.
5. If not found after that one attempt, stop searching web and use ctx7/find-docs.

Useful commands:

```bash
find ~/.sourcerer/repos -maxdepth 4 -type d -name .git -printf '%h\n'
git -C ~/.sourcerer/repos/github.com/owner/repo remote get-url origin
git -C ~/.sourcerer/repos/github.com/owner/repo fetch --tags --prune
```

## Step 3: Refresh Cached Repositories When Freshness Matters

Do not update every cached repository for every lookup. Refresh only when:

- the user asks for latest/current behavior,
- the answer depends on recent changes,
- the repo cache may be stale,
- the user explicitly asks to update cached repos.

Use the bundled updater from this skill directory:

```bash
scripts/update-repos.sh
```

Safe default behavior:

- scans `~/.sourcerer/repos`, or `$SOURCERER_REPOS` if set,
- skips dirty worktrees,
- fetches all remotes, tags, and prunes deleted refs,
- pulls with `--ff-only` only on clean branches with an upstream,
- fetches only for detached HEADs or branches without upstream,
- prints a summary of updated, fetched-only, skipped, and failed repos.

Useful modes:

```bash
scripts/update-repos.sh --dry-run
scripts/update-repos.sh --fetch-only
scripts/update-repos.sh --root ~/.sourcerer/repos
```

For one repo, prefer targeted commands instead of the bulk updater:

```bash
git -C ~/.sourcerer/repos/github.com/owner/repo fetch --all --tags --prune
git -C ~/.sourcerer/repos/github.com/owner/repo pull --ff-only
```

## Step 4: Search Source Locally

Search in this order for usage questions:

1. README, docs, guides, examples.
2. Tests and fixtures.
3. Public API exports.
4. Implementation source.
5. changelog/releases when version behavior matters.

Search in this order for implementation questions:

1. Exact symbols, function names, option names, error strings.
2. Public API entrypoints and exports.
3. Tests covering the behavior.
4. Internal implementation files.
5. Docs only to confirm intended behavior.

Useful commands:

```bash
rg "symbolOrOption" ~/.sourcerer/repos/github.com/owner/repo
rg "symbolOrOption" docs examples test tests packages src
rg "export .*Symbol|function Symbol|class Symbol" .
git grep "symbolOrOption"
```

Prefer reading specific files after 1-2 searches instead of endless grepping.

## Step 5: Cite with Immutable Permalinks

Every important implementation claim should have a source citation.

Get the commit SHA:

```bash
git -C ~/.sourcerer/repos/github.com/owner/repo rev-parse HEAD
```

Get the remote URL:

```bash
git -C ~/.sourcerer/repos/github.com/owner/repo remote get-url origin
```

Construct citations with full commit SHA and line ranges:

```md
https://github.com/owner/repo/blob/<commit-sha>/path/to/file.ts#L10-L30
```

Citation rules:

- Use full commit SHAs, not branch names.
- Cite exact line ranges.
- Cite tests when behavior is best proven by tests.
- Cite docs/examples for usage guidance.
- If source and docs conflict, prefer source and mention the conflict.
- If evidence is incomplete, say what is uncertain and show the evidence found.

## Step 6: History and Rationale Mode

For questions about why, when, regressions, or changes, use git history before speculating:

```bash
git -C ~/.sourcerer/repos/github.com/owner/repo log --oneline -- path/to/file.ts
git -C ~/.sourcerer/repos/github.com/owner/repo blame -L 10,40 path/to/file.ts
git -C ~/.sourcerer/repos/github.com/owner/repo show <sha> -- path/to/file.ts
```

Use GitHub CLI when PR/issue context matters:

```bash
gh search prs "keyword" --repo owner/repo --state merged --limit 10
gh search issues "keyword" --repo owner/repo --state all --limit 10
gh pr view <number> --repo owner/repo --comments
gh issue view <number> --repo owner/repo --comments
```

When citing history, include both source permalinks and relevant PR/issue links when available.

## Step 7: Version-Specific Research

If the user mentions a version, tag, release, or date:

1. Find the matching tag or commit.
2. Check out or inspect that version.
3. Answer from that version, not `main`.
4. Cite links using the exact commit SHA for that version.

Useful commands:

```bash
git -C ~/.sourcerer/repos/github.com/owner/repo tag --list '*1.2*'
git -C ~/.sourcerer/repos/github.com/owner/repo checkout <tag-or-sha>
git -C ~/.sourcerer/repos/github.com/owner/repo rev-parse HEAD
```

Return to the previous branch when done if needed.

## Step 8: ctx7/find-docs Fallback

Use ctx7/find-docs only when source-first research cannot answer well:

- No matching local repo exists.
- User did not provide a repo URL.
- The repo is private, unavailable, too large to inspect, or not the authoritative reference.
- The user asks a broad API usage question and source/examples are insufficient.
- The project has generated code or missing docs that make source hard to interpret.

Fallback rule:

```txt
local source → cloned source → repo docs/tests/examples → git history/PRs/issues → ctx7/find-docs → web search
```

When using ctx7/find-docs, make clear that the answer is documentation-backed rather than source-backed. If later a repo becomes available, prefer the repo.

## Video and Web Support

Video is not part of the normal source workflow. Use it only when the user provides a video URL/file or asks about a tutorial/talk.

For video, pass the user's exact question as the prompt. Use transcript, visual descriptions, timestamps, or frame ranges as needed.

Use web search only for:

- current release/news context,
- external discussions,
- ecosystem comparisons,
- missing PR/issue context,
- official docs that are not in the repo.

## Answer Style

Keep answers concise and evidence-backed:

- Start with the direct answer.
- Use bullets for findings.
- Include complete code snippets when giving usage examples.
- Include imports and setup when relevant.
- Link every non-obvious source claim.
- State uncertainty explicitly instead of overclaiming.
