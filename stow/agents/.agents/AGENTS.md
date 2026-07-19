# Global agent instructions

- When reporting information to me, be extremely concise and sacrifice grammar for the sake of concision
- Do not start subagents unless the user has explicitly requested it

## Critical workflow

- Prefer project-native tooling over ad-hoc commands.
- Before running JS/TS commands, detect the package manager from lockfiles (`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `bun.lockb`, `bun.lock`) and use that manager consistently.
- Prefer `package.json` scripts when they exist (for example use `check-types` instead of raw `tsc --noEmit`), unless the script is clearly unsuitable for the requested task.

## Library/repo research lookup order

- For source-code questions about libraries, frameworks, packages, or GitHub repos, use **sourcerer** first: local/cloned repo source, tests, examples, git history, PRs/issues, and source-backed citations.
- Use **librarian** for web/current/context research: articles, external discussions, release context, videos, or ecosystem information that source alone cannot answer.
- Use **find-docs** as the ctx7 reference fallback: when no usable source repo exists, source is insufficient, or official API docs are the clearest reference.


## Validation and browser testing

- After implementation, run relevant validation using existing project scripts where possible (for example: typecheck, lint, tests, browser verification).
- For browser testing/automation, use **chrome-devtools-cli + chrome-devtools skill**.
- Before any browser test run, check whether a dev server already exists by:
  - checking environment files for configured ports (`.env`, `.env.local`, `.env.example`), and
  - confirming with the user if server status is unclear.
- Never start an additional dev server when one may already be running; ask the user for permission or clarification instead.
