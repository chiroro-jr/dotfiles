# How to write a better `AGENT.md` file

An `AGENT.md` file contains instructions that are automatically added to an AI agent’s context. These instructions come after the system prompt, so they can guide behavior but do not override higher-priority instructions.

The purpose of `AGENT.md` is to help the agent perform better in a specific project. It should be used to reinforce important behaviors, reduce recurring mistakes, and provide guidance that is genuinely useful during task execution.

Because everything in `AGENT.md` consumes context, the file should be concise, specific, and intentional. Every instruction should earn its place. If a note is vague, redundant, or rarely useful, it is more likely to distract the agent than help it.

A good `AGENT.md` focuses on repeated patterns you want to encourage or prevent. It is most valuable when you have observed the agent behaving in a way that is consistently unhelpful and want to steer it more reliably. For example, if the agent keeps starting a new development server even though one is always running on port `3000`, a useful instruction might be: `Check whether a dev server is already running on port 3000 before starting a new one.`

It can also be used to remind the agent about steps it regularly forgets. For example, if it often finishes code changes without type-checking, you could add: `Run pnpm check-types after completing code changes.`

In general, do not use `AGENT.md` to duplicate information the agent can already discover from the codebase. If details already exist in files such as `package.json`, lint configuration files, build configuration files, or framework setup files, they usually do not need to be repeated. The agent can inspect those sources directly when needed.

Avoid putting fast-changing project details into `AGENT.md`. Instructions that reference specific dependency versions, scripts, or implementation details can become outdated as the project evolves. When that happens, the file creates unnecessary conflict between stale instructions and the current state of the codebase. Prefer stable guidance that remains useful over time.

Some information belongs in `README.md` rather than `AGENT.md`. If the content is mainly explanatory, descriptive, or intended for humans reading the project, it is often better placed in the README. `AGENT.md` should stay focused on operational guidance that improves agent behavior.

Do not generate an `AGENT.md` automatically and assume it will be good by default. The best instructions usually come from observing repeated issues in real usage and then adding targeted guidance to address them.

In short, use `AGENT.md` to:
- reinforce behaviors the agent often forgets
- prevent repeated mistakes
- provide concise, durable instructions that improve task execution
- avoid unnecessary duplication of information already available in the codebase

A strong `AGENT.md` is not a dump of everything important about a project. It is a short, high-value set of instructions that helps the agent focus on what matters most.

## Research-backed findings

The notes above match the direction of two evaluation papers on repository context files and agent skills.

### Repository-level context files can hurt performance when they are broad

`Evaluating AGENTS.md: Are Repository-Level Context Files Helpful for Coding Agents?` studied repository context files such as `AGENTS.md` and found:

- LLM-generated context files reduced success rates by about 3% on average.
- Developer-written context files improved success rates by about 4% on average.
- Context files increased cost by more than 20%.
- Agents tended to respect the instructions they were given.

The practical conclusion is important: extra requirements are not harmless. If an instruction is noisy, redundant, or unnecessary, the agent may still spend time following it.

This means a good `AGENT.md` should default to minimal requirements instead of broad repository narration.

### Unnecessary requirements make tasks harder

The same paper found that context files often caused broader exploration, including more testing and file traversal. The paper’s conclusion was that unnecessary requirements make tasks harder, and that human-written context files should describe only minimal requirements.

In practice:

- Keep only instructions that prevent recurring mistakes or encode a real repo-specific workflow.
- Avoid mandatory checklists that apply to every task unless they have clear payoff.
- Be suspicious of anything that makes the agent explore more without materially improving the chance of success.

### Repository overviews are usually weak value

Many generated context files included repository overviews, but those overviews did not function as effective repository guidance.

This lines up with the practical rule above: do not duplicate what the agent can already recover cheaply from the codebase. Folder tours, architecture summaries, dependency lists, and explanations copied from `README.md` are usually not good use of context budget unless they directly change how the agent should act.

### Human-curated procedural guidance helps more than self-generated guidance

`SkillsBench: Benchmarking How Well Agent Skills Work Across Diverse Tasks` studied structured agent skills and found:

- Curated skills improved pass rate by 16.2 percentage points on average.
- Self-generated skills provided no benefit on average and were about -1.3 percentage points on average.

The lesson for `AGENTS.md`-style files is that auto-generated instruction files should not be trusted by default. The best instructions are usually shaped by real failure modes, real workflows, and human curation.

### Focused instructions beat comprehensive documentation

The same skills paper found that focused skills with 2-3 modules outperformed comprehensive documentation.

That suggests a good repository instruction file should be short and structured. A useful default shape is:

1. `Critical workflow`
2. `Validation`
3. `Repo-specific hazards` or `Repo conventions`

If one section is empty, omit it. The point is focus, not template compliance.

### Procedural guidance matters more than descriptive text

The skills paper distinguishes procedural knowledge from descriptive documentation. Useful guidance tells the agent how to act: steps, workflows, SOPs, decision rules, examples, and resources.

For `AGENT.md`, this means:

- Keep instructions that change behavior.
- Remove or relocate content that only explains the repository.
- Prefer exact commands, scope rules, and decision rules over general prose.

### Durable guidance beats volatile detail

Instructions in `AGENT.md` should remain true for a while. Fast-changing dependency versions, fragile file lists, temporary workarounds, and stale commands create conflict between the instruction file and the actual repo.

If a detail changes often, it probably belongs in code, config, tests, or human documentation rather than agent instructions.

## Audit rubric

When reviewing an existing file, use these questions:

1. Does this sentence change what the agent should do?
2. Is it repo-specific and procedural?
3. Would a capable agent discover this cheaply from the repo anyway?
4. Does it prevent a known repeated mistake?
5. Will this still be true in a few months?
6. Does it add mandatory work for every task?

If the answer pattern is weak, cut or rewrite the instruction.

## Keep, rewrite, remove

### Keep

- Exact build, test, lint, or validation commands
- Explicit triggers for when to run them
- Repo-specific workflow constraints
- Known hazards, gotchas, or invariants
- Short decision rules the agent would not infer reliably

### Rewrite

- Useful instructions expressed vaguely
- Commands without scope or triggers
- Overlong sections that contain one good rule buried in explanation
- Mixed sections that combine operational guidance with human onboarding

### Remove

- Generic coding advice
- Repository summaries and folder tours
- Repetition of `README.md` or config facts
- Fast-changing implementation details
- Requirements with no clear payoff

## Preferred shape for a strong file

Aim for a short file with 2-3 sections:

1. `Critical workflow`
   Include the small number of commands and task-routing rules the agent must know.

2. `Validation`
   Include which checks to run, when to run them, and any scope rules.

3. `Repo-specific hazards`
   Include invariants, forbidden shortcuts, or places agents commonly break things.

This is a guideline, not a fixed template.
