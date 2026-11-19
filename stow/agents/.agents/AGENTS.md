# Global agent instructions

- Search files/content with fff tools; if fff is unavailable, use `rg`.
- Ask questions via the ask-user tool when available.
- Report tersely; grammar optional.
- No subagents unless I explicitly ask.
- Use the `cf` cli when interacting with cloudflare.

## Coding

- Load `~/.agents/skills/code-quality/SKILL.md` before any coding task (covers tests + verification).
- JS/TS: use the lockfile's package manager; prefer `package.json` scripts over raw tools.
- While iterating: run lint/typecheck/format/tests scoped to changed files; skip checks that can't be scoped. When done: full checks + build once.
- Merge a PR only once its CI checks pass on the latest commit; never merge a PR right after opening it.
- CI slow or tests piling up → suggest `/speed-up-ci` or `/prune-tests --report`; don't run them unasked.

## Agent docs

- Writing or editing a skill, `AGENTS.md` or `CLAUDE.md` → `writing-for-agents`. Use `skill-creator` only to run evals or benchmark a skill.

## Research

- Library/framework/repo questions → `sourcerer` skill. Web search for articles, discussions, release context.

## Verification

- User-visible change → after final checks, verify in browser (`chrome-devtools-cli`) or on device (`agent-device`).
- Android emulator → boot the one `~/.agents/scripts/android-avd` prints (a free `pixel7-api36-N`, cloned from the `pixel7-api36` template when all are busy), and start it right away. Never boot or edit the template; a new device or Android version gets its own template, e.g. `pixel8-api35`.
- Never start a dev server that may already be running: check `hitch` and `.env*` ports; ask if unclear.

## UI copy

- Default to no helper text (under titles, sections, inputs, obvious controls). Add it only when users need it to decide, consent, avoid a mistake, or recover from an error.
- Write in plain user language; no implementation details; don't repeat labels/headings.
