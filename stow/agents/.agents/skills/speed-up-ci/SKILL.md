---
name: speed-up-ci
description: Measure where a repo's CI minutes go and cut the biggest cost first.
disable-model-invocation: true
---

# Speed up CI

CI time is pushes × runs per push × minutes per run. Measure all three before changing anything, then fix in order of minutes saved per day.

## 1. Measure (GitHub Actions)

From the last ~150 runs (`gh run list --json`, jobs via `gh api repos/OWNER/REPO/actions/runs/RUN/jobs`):

- **Per job: wait, setup, run.** Wait = `started_at − created_at` from the jobs API (`gh run view --json jobs` omits creation time). Setup = steps before the test/build step.
- **Runs per merged PR**, and how many only followed an update from main.
- **Wasted minutes**: share on runs that failed, were cancelled, or were superseded by a newer push.
- **Flaky rate**: runs that failed, then passed on a rerun of the same commit.
- **Caches**: hit rate per job, restore time vs the step it replaces, `gh api repos/OWNER/REPO/actions/cache/usage` against the 10 GB limit.
- **Suite growth**: median minutes per run and test count, month by month.
- **Merges without a green PR run**: PRs merged before their run finished re-run the full suite on the target branch, and leave it red when they fail.
- **The test process itself**, on one real run: CPU use against available cores, and peak memory. Low CPU with many tests in flight means something throttles them; memory that only grows means test hosts or fixtures leak.

Wall time is what you save. Test reports sum durations across parallel tests, so a test file's summed seconds overstate its effect by roughly the parallelism; divide by it before ranking. Only the slowest job on the path to a green PR sets the wait.

## 2. Fix, biggest measured cost first

Each fix has a known way to backfire; check it.

| Fix | Backfires when | Check |
|---|---|---|
| Cancel superseded PR runs (never on main) | — | wasted-minutes share |
| Fast checks only until a PR leaves draft | — | runs per merged PR |
| Skip jobs a diff can't affect; run diff-selected tests on PRs, everything on main | a skip reports green | break a file on purpose; CI must go red |
| Turn off "require branches up to date"; test once at merge (merge queue). Remove `gh pr update-branch` from agents' auto-allowed commands | PRs are short anyway | runs per merged PR, before/after |
| Fold tiny jobs together | — | setup seconds per job |
| Fix cache keys (include tool version, one key per job); save caches on main | restore is slower than the work it skips | hit rate; restore vs replaced step |
| Blobless checkout, install only what the job uses | something reads git history (shallow clones break it) | setup seconds |
| Match test workers to cores before adding shards; shard by recorded time | per-shard setup dominates; tests share state | slowest shard, total runner minutes |
| .NET test hosts: free each `WebApplicationFactory` (look for per-host loggers, timers, statics that root it), then Server GC (`DOTNET_gcServer=1`, `DOTNET_GCDynamicAdaptationMode=1`) | Server GC raises memory while a leak remains | retained MB per host; step time; peak RSS |
| One host or fixture per test class instead of per test | tests share state | step time; flake rate |
| Flutter/Dart: per-file compilation dominates `flutter test`; run a few generated entry files that import many tests | tests that assumed their own isolate fail | step time; test count unchanged; a deliberate break still fails |
| Wait for the PR run before merging | slower merges until the suite is fast | share of target-branch runs that re-test; red rate |
| Build images or artifacts only where they are deployed, not on every PR | — | image-job minutes by event |
| Faster tools (tsgo, oxlint, uv) | the tool wasn't the slow part | whole-job time, a few runs each side |
| Bigger or faster runners, last | no queue to remove | CPU use first; the bill after |
| Flaky test: reproduce by running it many times, fix the cause; lint-ban retries, sleeps, per-test timeouts, and untracked skips | — | red-then-green count on the same commit |
| Too many tests: run `/prune-tests` (usually a maintenance win; check its wall-time share first) | the cut loses real coverage | its step-4 break-the-code check |

## 3. Guardrails for the loop

- One target number, measured on real CI runs, a few on each side; laptop timings don't transfer.
- A floor: the test count and the break-a-file check hold, so speed never comes from silently dropping coverage.
- A cap on the CI minutes the loop itself may spend.
- Local hooks fast and diff-scoped; the required check stays on the server.

## Done

A before/after table of the measured numbers from step 1, each change linked to the number it moved, and the break-a-file check passing.

Based on Matt Gapp, ["CI becomes exponentially slower as you increase PR velocity"](https://x.com/mattgapp/status/2122457922601198074), and [OpenClaw's CI cost reduction](https://vincent.build/openclaw-ci-cost-reduction/).
