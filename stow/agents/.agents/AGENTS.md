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


## Tests

Before adding, changing, or removing tests, give a short justification:
- Identify the concrete failure and its user-visible or API consequence.
- Explain why existing tests do not catch it.
- Rank proposed tests by value: reproduced bugs first, then specific regression risks or consequential public contracts.
- For removals, explain why protection is obsolete, redundant, or misplaced.

Drop candidates without a concrete failure and consequence. No new test is an acceptable outcome. Do not invent requirements to justify tests.

Prefer the smallest public-behavior test that catches the failure. For bug fixes, demonstrate failure before the fix when practical.

Do not add tests solely for coverage, cosmetic details, implementation structure, or the presence/absence of something just edited. Avoid broad snapshots and tests of dependency internals.

Use deterministic inputs and controlled time/network where needed. Match the existing runner and layout. New test files are allowed; new runners or test infrastructure require separate justification.

Follow the justified plan. Revise it before making additional test changes.

## Validation and browser testing

- After implementation, run relevant validation using existing project scripts where possible (for example: typecheck, lint, tests, browser verification).
- For browser testing/automation, use **chrome-devtools-cli + chrome-devtools skill**.
- Before any browser test run, check whether a dev server already exists by:
  - checking environment files for configured ports (`.env`, `.env.local`, `.env.example`), and
  - confirming with the user if server status is unclear.
- Never start an additional dev server when one may already be running; ask the user for permission or clarification instead.
