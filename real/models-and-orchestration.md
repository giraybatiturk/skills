# Models and orchestration

Choose models by capability, not by pinned version.
The README model table and `real-audit` `references/orchestration.md` hold the full tables. This file keeps only the extras.

## Orchestration triggers
- The five triggers in this repo's README are canonical. Full list: `real-audit` `references/orchestration.md`.
- Split the work across agents when any one trigger is true. Otherwise do it alone.
- Split format: at least two independent views, plus one adversarial verifier.
- The verifier cannot be cheaper than the producer.
- An unneeded agent is waste. Spending 400K tokens on a single decision is not worth it for a rename job.
<!-- Why: Independent checks catch what one agent misses, but are wasted on trivial jobs. -->

## Roles and tiers
- The main session manages: scope, decisions, talking to the user, reading verification results, one-line fixes.
- Agents do file scanning, multi-file editing, translation, documents and research. Do not do these by hand in the main session.
- Same split in every client (Claude Code, omp, Codex):
  - The upper tier (Opus) plans, analyses and decides.
  - A dedicated coding agent on the mid tier (Sonnet) writes the code.
  - The upper tier reviews that code against the plan, every round.
- The strongest tier (Fable) and a second model family (Codex) are optional second opinions only.
- They never replace the upper-tier reviewer. They are never the lead.
- Where the README table prefers the strongest tier for architecture, this rule narrows that to an optional second opinion.
<!-- Why: One clear plan, build, review loop is easier to trust than a changing lead. -->
- Tiers by capability:
  - Fastest (haiku): discovery, grep, inventory, commit messages. Writes no code, verifies nothing.
  - Mid (sonnet): mechanical fixes, translation, documents, research sweeps.
  - Upper (opus): planning, multi-file reasoning fixes, adversarial verification, final judgment.
- If the mid tier produced, the upper tier verifies.
- After every agent round that changes code, build and tests run in the main session.
- Do not accept a "does not exist" claim from the fastest tier. A stronger tier verifies it.
<!-- Why: A cheap model once reported something missing that did exist. A verifier at least as strong as the producer catches this. -->
- Pass the model explicitly on every agent or workflow call. Never leave it empty (it falls back to the strongest model).
- At most 3 agents in parallel. Discovery and scanning on the fastest tier.
- Four or more agents only when the user explicitly asks (see `mac-only.md`).

## Claude Code / omp only
- Write code with a dedicated coding agent on the mid tier at high effort. Use it for a new feature, phase, screen or multi-file work. Do not use the generic built-in agent.
- Fallback: set the high effort level for that model in the client settings.
- "Quick" requests: send code work to a coding agent at low effort. Build, test and verifier rules do not change.
- The main session chooses effort per job. An agent cannot change its own effort.
- New feature, screen, multi-file or reasoning-heavy work: high-effort coding agent.
- Small, well-defined single-file work: low-effort coding agent.
- Listed mechanical fixes: medium-effort agent.
- If unsure, use high. State the choice in one line when starting the agent.
<!-- Why: Effort is fixed in an agent's definition, so the caller must pick the right agent for the job. -->
- Model aliases (haiku, sonnet) move to new versions. Check what an alias resolves to in the installed client.
- Prompts above about 100K tokens cost a premium. In a large repository, scan folder by folder.

## Second opinions
- The strongest-tier check is optional. Use it when worth the cost, for example before a store or beta upload, or on work over 10 files. State the reason.
- The second-model-family check is optional. A read-only agent on another model family reviews the diff. It writes no code.
- It may run in addition to the upper-tier reviewer on externally visible or over-10-file work. Never instead of it. Same in every client.
- Agent names, versions and the old source lines are kept in the private overlay.
<!-- Why: A different model family has different blind spots, but it only adds a view. It does not replace the reviewer. -->
