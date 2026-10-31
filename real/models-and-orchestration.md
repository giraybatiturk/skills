# Models and orchestration

Choose models by capability, not by pinned version.
The README model table and `real-audit` `references/orchestration.md` have the full tables. This file has only the extra rules.

## Orchestration triggers
- The triggers in the README Orchestration section are canonical. `real.md` lists them.
- `real-audit` `references/orchestration.md` has the full list and the execution contract.
- Split the work across agents when one trigger is true. If none is true, do the work alone.
- Use at least two independent views and one adversarial verifier.
- The verifier cannot be cheaper than the producer.
- An agent that is not needed is waste. Do not spend 400K tokens on a single decision for a rename job.
<!-- Why: Independent views find what one agent misses. They are waste on trivial jobs. -->

## Roles and tiers
- The main session manages: scope, decisions, talks with the user, reads verification results, makes one-line fixes.
- Agents do file scanning, multi-file editing, translation, documents and research. Do not do these by hand in the main session.
- Use the same split in every tool (Claude Code, omp, Codex):
  - The upper tier (Opus) plans, analyses and decides.
  - A dedicated coding agent on the mid tier (Sonnet) writes the code.
  - The upper tier reviews that code against the plan, in every round.
- The strongest tier (Fable) and a second model family (Codex) give optional second opinions only.
- They never replace the upper-tier reviewer. They are never the lead.
- The README table prefers the strongest tier for architecture. This rule changes that to an optional second opinion.
<!-- Why: One plan, build and review loop is easier to trust than a changing lead. -->
- Tiers by capability:
  - Fastest (haiku): discovery, grep, inventory, commit messages. It writes no code and verifies nothing.
  - Mid (sonnet): mechanical fixes, translation, documents, research sweeps.
  - Upper (opus): planning, multi-file reasoning fixes, adversarial verification, final judgment.
- If the mid tier produced the work, the upper tier verifies it.
- After every agent round that changes code, run the build and tests in the main session.
- Do not accept a "does not exist" claim from the fastest tier. A stronger tier verifies it.
<!-- Why: A cheap model reported that something was missing, but it existed. -->
- Give the model explicitly on every agent or workflow call. Do not leave it empty. An empty model falls back to the strongest model.
- Run at most 3 agents in parallel. Run discovery and scanning on the fastest tier.
- Run 4 or more agents only when the user asks. The limit protects the load of the local machine.

## Claude Code / omp only
- Write code with a dedicated coding agent on the mid tier at high effort. Use it for a new feature, phase, screen or multi-file work.
- Do not use the generic built-in agent for this work.
- Fallback: set the high effort level for that model in the tool settings.
- "Quick" requests: send code work to a coding agent at low effort. The build, test and verifier rules do not change.
- The main session chooses the effort for each job. An agent cannot change its own effort.
- For a new feature, screen, multi-file or reasoning-heavy work, use a high-effort coding agent.
- For small, well-defined single-file work, use a low-effort coding agent.
- For listed mechanical fixes, use a medium-effort agent.
- If you are not sure, use high. State the choice in one line when you start the agent.
<!-- Why: The definition of an agent fixes its effort. The caller must pick the right agent. -->
- Model aliases (haiku, sonnet) move to new versions. Find what an alias resolves to in the installed tool.
- Prompts above about 100K tokens cost a premium. In a large repo, scan folder by folder.

## Second opinions
- The strongest-tier check is optional. Use it when it is worth the cost. Examples: before a store or beta upload, or for work over 10 files.
- State the reason when you use it.
- The second-model-family check is optional. A read-only agent on another model family reviews the diff. It writes no code.
- It can run in addition to the upper-tier reviewer on externally visible work or on work over 10 files. Never use it instead of the reviewer.
- This rule is the same in every tool.
- Keep agent names, versions and the old source lines in the private overlay.
<!-- Why: Another model family has other blind spots. It adds a view and does not replace the reviewer. -->
