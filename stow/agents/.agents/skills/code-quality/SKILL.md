---
name: code-quality
description: Rules for writing, changing, debugging, testing, and reviewing code. Use for every coding task.
---

# Code quality

Write for the next person who changes this code without this conversation.

## Before you change code

- Reuse first: search sibling modules for an existing type, helper, or policy, and put the change in the module that owns the behavior.
- Decide the check that would fail on the old behavior and pass on the new one. A run that merely succeeds proves nothing.

## While changing

- Keep a refactor separable from a behavior change. Preserve return values, errors, ordering, and side effects unless the task changes them.
- Add an abstraction only when it hides real complexity or unifies one rule across existing callers.
- Validate external input once, at the boundary. Narrow unknown data with real checks; casts and `any` are not validation.
- Let failures surface: handle an error where you can recover or add context, and keep its cause. A success-shaped default or a retry over an unexplained defect hides the bug.
- Authentication is not authorization: check owner/tenant access for every resource the change touches.
- Dependency upgrades: read the release notes, regenerate the lockfile with the package manager, and review its diff for transitive changes.
- Justify caching, concurrency, and new dependencies with a concrete need. Check for N+1 queries and unbounded fetches.

## Bugs

Reproduce, state a falsifiable cause, fix at the cause. When a fix fails, revise the explanation with the new evidence instead of stacking another patch.

## Tests

A test earns its place by catching a named failure that existing tests miss.

- Before adding one, name that failure. If you can't, add no test.
- Prefer one regression test that fails before the fix and passes after.
- Assert observable behavior through the smallest public boundary, with expected values from the requirement, not copied from the implementation.
- Leave out tests for coverage numbers, trivial forwarding, dependency internals, and broad snapshots.
- To show the test catches the bug, run it before applying the fix, or in a copy of the repo. Uncommitted work in the tree is the user's: leave the working tree to your own edits, with no `stash`, `reset`, or `checkout` of files.

## Verify

- Read the checker's own output. Zero tests discovered, skipped suites, or a bare HTTP 200 is not a pass; confirm the intended cases ran.
- Exercise the changed path directly when no check covers it.
- Read the full diff: the new path is wired in, and helpers it made obsolete are gone.

## Reviews

Review-only requests stay read-only. Report each finding with location, trigger, consequence, and fix; "no findings" is a valid result.

## Hand-off

State the outcome, the checks you actually ran, and remaining gaps, separating what you observed from what you inferred.
