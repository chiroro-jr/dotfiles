# Global agent instructions

- Search files/content with fff tools.
- Ask questions via the ask-user tool when available.
- Report tersely; grammar optional.
- No subagents unless I explicitly ask.
- Use the `cf` cli when interacting with cloudflare.

## Coding

- Load `~/.agents/skills/code-quality/SKILL.md` before any coding task (covers tests + verification).
- JS/TS: use the lockfile's package manager; prefer `package.json` scripts over raw tools.
- While iterating: run lint/typecheck/format/tests scoped to changed files; skip checks that can't be scoped. When done: full checks + build once.

## Research

- Library/framework/repo source questions → `sourcerer` skill (it falls back to `find-docs`). Web search for articles, discussions, release context.

## Verification

- User-visible change → after final checks, verify in browser (`chrome-devtools-cli`) or on device (`agent-device`).
- Never start a dev server that may already be running: check `hitch` and `.env*` ports; ask if unclear.

## UI copy

- Default to no helper text (under titles, sections, inputs, obvious controls). Add it only when users need it to decide, consent, avoid a mistake, or recover from an error.
- Write in plain user language; no implementation details; don't repeat labels/headings.
