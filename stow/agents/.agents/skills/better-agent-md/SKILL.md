---
name: better-agent-md
description: Audit, improve, or rewrite repository-level agent instruction files such as AGENTS.md, AGENT.md, CLAUDE.md, GEMINI.md, or repo-specific agent context files. Use when Codex needs to review an existing instruction file for weak points, explain why it may hurt agent performance, suggest concrete fixes, or produce a tighter replacement grounded in the codebase and research on agent context files and skills.
---

# Better Agent MD

Treat agent instruction files as operational guidance, not general documentation.

## Workflow

1. Find the target file and read it fully.
2. Read only the codebase files needed to verify its claims and commands.
3. Read `references/how-to-write-a-better-agent-md.md` before giving recommendations.
4. Use it as the only reference unless the user gives new source material.
5. Classify every instruction as one of:
   - Keep: repo-specific, procedural, durable, and hard for the agent to infer cheaply.
   - Rewrite: useful idea, but vague, bloated, redundant, or too broad.
   - Remove: redundant overview, fast-changing detail, human-facing documentation, or unnecessary requirement.
6. Produce both critique and remediation. Do not stop at observations alone.

## What To Optimize For

- Minimize requirements. Extra mandatory steps increase cost and can make tasks harder because agents tend to follow them literally.
- Preserve only high-value procedural guidance: commands, workflows, validation steps, repo hazards, and project-specific conventions.
- Prefer focused instruction sets over comprehensive repository summaries.
- Keep guidance stable over time. Move volatile details out of the agent file unless they are critical and easy to verify.
- Prefer instructions tied to repeated failure modes or recurring agent mistakes.
- Tie recommendations to execution impact, not style preference alone.

## Review Rubric

Check each section and instruction against these questions:

1. Is this instruction actionable?
   Good: `Run pnpm test:unit for files under src/foo/.`
   Bad: `Be careful and follow best practices.`

2. Is this instruction procedural rather than descriptive?
   Keep workflows, commands, and decision rules.
   Remove broad repository summaries the agent can recover by inspecting the codebase.

3. Is this instruction repo-specific?
   Keep details that reflect this repository's tooling, hazards, or conventions.
   Remove generic advice that belongs in the system prompt or the model already knows.

4. Is this instruction durable?
   Rewrite or remove version numbers, file inventories, and implementation details that will drift quickly.

5. Is this instruction necessary?
   If it adds friction without preventing a known mistake, cut it.

6. Can the agent verify it cheaply?
   Prefer commands and checks the agent can run or confirm from the repo.
   Mark uncertain statements instead of turning guesses into rules.

## Common Weak Points

- Auto-generated repository overviews that restate README or source layout.
- Long lists of style rules with no concrete enforcement path.
- Mandatory steps for every task when they are only needed in specific cases.
- Instructions that mix human onboarding material with agent execution guidance.
- Conflicting goals such as `be exhaustive` and `be minimal` without decision rules.
- Commands that no longer exist or no longer match the repository.
- Requirements that broaden exploration without increasing success odds.

## Fix Patterns

- Replace prose summaries with short operational sections.
- Convert vague advice into explicit triggers and actions.
- Move explanatory material to `README.md` or other docs.
- Keep only the minimum repo-specific rules that materially change agent behavior.
- Group content into 2-3 short modules when possible:
  - Critical workflow
  - Validation and tests
  - Repo-specific hazards or conventions

## Expected Output

When asked to review an existing file, return:

1. `Findings`
   Identify weak points, why they matter, and whether each item should be kept, rewritten, or removed.

2. `Improved draft`
   Provide a revised file or a patch, not only commentary.

3. `Rationale`
   Tie major changes back to concrete principles from `references/how-to-write-a-better-agent-md.md`.

4. `Open questions`
   List only the missing repo facts that block a confident rewrite.

If the user asks for a fix, default to editing the file directly or providing a ready-to-apply replacement.

## Writing Rules For The Replacement

- Use short sections and direct imperative language.
- Prefer bullets over long paragraphs.
- Keep each bullet single-purpose.
- Avoid duplicating information the agent can discover from config files or code.
- Do not promise workflows you did not verify.
- If the existing file is mostly noise, rewrite from scratch instead of editing line by line.
