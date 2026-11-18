---
name: code-quality
description: >-
  Must always be applied to every coding task, including writing, modifying,
  debugging, refactoring, testing, and reviewing code. Produces correct,
  maintainable code that other agents and human developers can understand,
  change, and review. Apply proactively without an explicit request.
---

# Code quality

Make the requested behavior correct and the implementation understandable without the conversation that produced it. Optimize for the next person or agent who must change the code.

Apply these principles throughout the task. Scale effort to the change and its consequences. A small edit needs a small check, not a new planning process. Respect user instructions, repository conventions, and authorized scope. Review-only requests remain read-only.

## Understand the change

- Identify the observable result, compatibility constraints, and behavior that must remain unchanged. Resolve consequential ambiguity before relying on it.
- Read the relevant implementation, callers, and tests. Search sibling modules for existing types, helpers, and policies before creating equivalents. Follow the module that already owns the behavior.
- Inspect repository instructions and native tooling. For JS/TS, determine the package manager from lockfiles and package metadata; use existing project scripts. Verify unfamiliar dependency behavior against the installed version's source or official documentation.
- Choose a check that distinguishes the requested outcome from the old behavior. Successful execution alone may not prove the change worked.

## Keep the design easy to change

- Keep each business rule in its owning module. Separate calculations and decisions from storage, network calls, and presentation when that makes dependencies and tests clearer.
- Add an abstraction when it hides meaningful complexity, enforces an invariant, or unifies the same rule across real callers. Similar-looking code alone does not justify shared machinery. Avoid speculative extension points and wrappers that only forward arguments.
- When branches accumulate, inspect the state model and ownership. Prefer removing an unnecessary state or duplicated decision over scattering more flags. Introduce a dispatcher or state machine only when the actual transitions justify it.
- Group code by responsibility and reasons to change. Split a module when it mixes responsibilities or obstructs understanding. Line counts are clues, not automatic failure thresholds; extra files and indirection also cost the reader.
- Use domain names that reveal purpose. Make units, ordering, optionality, and side effects clear where they matter. Prefer explicit control flow over nested ternaries or compressed expressions that require mental simulation.
- Make invalid states hard to represent. Validate external input at a clear boundary, then use the established internal contract. Narrow unknown data honestly; do not replace validation with casts, `any`, or blanket suppression.
- Preserve useful comments about intent, invariants, compatibility, and surprising constraints. Remove comments that merely narrate the code. Document changed public contracts where callers look for them.

## Preserve behavior and failure semantics

- Keep refactoring distinguishable from behavior changes. Preserve return values, errors, ordering, side effects, and compatibility unless the task requires changing them. Limit cleanup to the affected design.
- Handle errors where the program can recover or add useful context. Preserve the cause. Do not swallow failures, return success-shaped defaults, or add retries to conceal an unexplained defect.
- For shared state or external effects, check partial failure, duplicate execution, cancellation, and ordering as relevant. Use existing transaction or idempotency mechanisms when the operation requires them. Parallelize only genuinely independent work with understood failure behavior.
- Trace trust boundaries before adding or removing safeguards. Logged-in users can still access another user's or tenant's resources incorrectly. Check the relevant authorization and data flow; neither authentication nor a framework name proves safety.
- Justify dependencies, caching, concurrency, and performance changes with a concrete requirement or observed bottleneck. Prefer the smallest design that meets it.
- For dependency upgrades, read release notes and migration guidance. Review manifest and lockfile diffs for direct and transitive changes; regenerate lockfiles with the package manager. Keep unrelated upgrades separable when practical. Verify affected behavior; successful installation is insufficient.
- Check for introduced N+1 queries, unbounded work or fetching, missing pagination, and repeated work in hot paths. Assess realistic data sizes and call frequency. Support findings with query counts, complexity analysis, or measurements; do not invent timing estimates.

## Diagnose before fixing

Reproduce the failure when practical. Inspect the failing input, execution path, recent changes, and a comparable working case. State a falsifiable cause and use a narrow check to distinguish it from alternatives. Keep diagnostics scoped and avoid exposing secrets.

Fix the cause at the appropriate boundary. If an attempt fails, use the new evidence to revise the explanation instead of stacking speculative patches. Repeated failures warrant reassessing assumptions and coupling. Describe an unconfirmed cause as a hypothesis.

## Make tests earn their maintenance cost

- Before adding, changing, or removing tests, briefly name the concrete failure and its user-visible or API consequence, the gap in existing protection, and the smallest useful test change. Prioritize reproduced bugs, then specific regression risks and consequential public contracts. Explain why removed protection is obsolete, redundant, or misplaced.
- Derive expected results from requirements or independently checked examples. Exercise observable behavior through the smallest suitable public boundary. Avoid assertions on private structure, copied implementation logic, mock behavior alone, or source text that merely records the current implementation.
- For a reproducible bug or new behavior, prefer a test that fails for the intended reason before the change and passes afterward. Existing passing tests can protect a pure refactor; do not manufacture a failure or rewrite correct work to satisfy a ritual.
- Use the existing runner, file layout, and controlled inputs. Control time, randomness, and network boundaries where necessary. Include realistic interaction cases when isolated examples would miss the actual failure.
- Add no test when existing protection and an appropriate direct check suffice. Avoid tests for coverage numbers, trivial forwarding, cosmetic choices, dependency internals, or broad snapshots. Do not introduce a runner solely to test a low-impact edit.
- When demonstrating a regression by temporarily breaking code, use an isolated copy or preserve the exact current files. Restore only the deliberate mutation. Never discard uncommitted work to recover a baseline.

## Review the result and verify the claim

Read the complete diff, surrounding code, and affected callers. Check that the new path is actually connected, removed safeguards are unnecessary, and public contracts still hold. Consult history when the reason for an existing constraint is unclear.

Check for helpers, imports, types, and configuration made obsolete by the change. Remove confirmed-unused internal code within scope. Before deleting exports or dynamically loaded code, check supported callers and registrations; a search with no matches alone does not establish disuse.

Review correctness and consequential regressions first, then design and readability. For each structural change, identify what became easier to understand or modify. Reject cleanup that merely relocates complexity, broadens scope, or weakens checks to obtain a pass.

Run relevant project checks against the final changes. Read the checker's own result, including failures, errors, skipped checks, and whether the intended cases ran. A wrapper's successful exit, zero discovered tests, or an HTTP success code alone does not prove the requested behavior. Exercise the changed user or API path when existing checks do not cover it. Reuse results for unchanged code; rerun affected checks after further edits.

In reviews, report actionable findings with location, triggering condition, consequence, and a specific remedy. Separate impact from confidence. Label unresolved suspicions as needing verification and omit unsupported warnings or preference-only blockers. No findings is a valid result.

When preparing a commit or PR, make its description stand alone. Explain the behavior change, why it is needed, material tradeoffs, and validation. Preserve rationale absent from the code so future readers need not recover this conversation.

At handoff, state the outcome, material design choices, checks actually run, and remaining gaps. Distinguish observed results from inference. Stop when the requested behavior is satisfied, appropriate checks are complete, and remaining changes would be speculative or cosmetic.
