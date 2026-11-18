---
name: prune-tests
description: Audit a test suite and delete tests that guard no behavior.
disable-model-invocation: true
argument-hint: "[path] [--report]"
---

# Prune tests

Every test must guard intended behavior: it changes only when that behavior changes, and fails only when it regresses. Prune the rest.

With `--report`, change nothing: produce the audit table and the summary only.

## 1. Baseline

Run the scoped suite and record: test count, test lines, runtime. It must be green; pruning on red hides regressions. If the repo uses GitHub Actions, also record median test-job minutes from recent runs (`gh run list`, `gh run view --json jobs`).

## 2. Audit, one subsystem at a time

For each test, write down the behavior it guards and one plausible bug that would fail it. A test with no answer to both guards nothing. Then classify what it depends on:

- **Past**: asserts removed code stays gone (a deleted feature, a module absent from its old path). Bringing it back would be a decision, not a regression.
- **Nothing**: no change to the code can fail it. It tests the framework, browser, ORM, or DI container; mocks the unit under test and asserts the mock; asserts what the type system guarantees; asserts a constant or a config value against itself.
- **Implementation**: it fails when the code changes but behavior doesn't. The expected value is recomputed with the code's own logic; it asserts private state, internal call order, or which helper ran; it snapshots incidental structure.
- **Duplicate**: another test guards the same behavior through the same boundary. Keep the strongest one per contract; a unit test and an integration test of one rule are duplicates when they would fail on the same bugs.

Behavior-anchored tests stay, however small.

## 3. Prune

- Delete tests in the four classes above.
- When a test also covers behavior callers rely on, rewrite it against that behavior instead.
- Delete production code that existed only for removed tests (`_resetForTests`, test-only exports and flags).

## 4. Prove nothing real was lost

For each contract whose tests you deleted or rewrote, break the production code on purpose with a throwaway edit and confirm a remaining test fails, then revert the edit. If none fails, the contract lost its guard: restore or write the one test that fails.

## Done

- Suite green; every remaining test names its behavior; one test per contract.
- Report: tests, test lines, and runtime before and after (CI minutes if measured); deletions grouped by class with a one-line reason each; contracts checked in step 4; anything left uncovered.

Adapted from [caldoai/skills `prune-tests`](https://github.com/caldoai/skills/blob/main/skills/prune-tests/SKILL.md) (MIT) and [OpenClaw's CI cost reduction](https://vincent.build/openclaw-ci-cost-reduction/).
