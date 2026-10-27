# Models and orchestration

Models are chosen by capability, not by pinned version. The README model table and `real-audit` `references/orchestration.md` already say this and hold the full tables; this file keeps the deltas.

## Orchestration triggers
The canonical triggers are the five in the Orchestration section of this repo's README; the full numbered list and the execution contract are in `real-audit` `references/orchestration.md`. This file does not restate them, so there is only one list to maintain.
- Split the work across agents when any one of those five triggers is true; otherwise do it alone. An unneeded agent is waste; spending 400K tokens on a single decision is not worth it for a rename job.
- Split format: at least two independent views (unaware of each other, from different angles) plus one adversarial verifier. The verifier cannot be cheaper than the producer.

## Roles and tiers
- The main session manages: scope, decisions, talking to the user, reading verification results, one-line fixes. File scanning, multi-file editing, translation, documents and research go to agents; do not do them by hand in the main session.
- Division of work, the same in every client (Claude Code, omp, Codex): the upper tier (Opus) plans, analyses and decides; a dedicated coding agent on the mid tier (Sonnet) writes the code; the upper tier reviews that code against the plan, every round.
- The strongest tier (Fable) and a second model family (Codex) are optional second opinions only. They never replace the upper-tier reviewer and are never the lead. Where the README model table prefers the strongest tier for architecture, this rule narrows that to an optional second opinion.
- Tiers by capability: discovery, grep and inventory go to the fastest tier (haiku; touches no code, writes no code, verifies nothing, also fine for commit messages); mechanical fixes, translation, documents and research sweeps go to the mid tier (sonnet); planning, multi-file reasoning fixes, adversarial verification and final judgment go to the upper tier (opus). The strongest reasoning model is an optional second opinion, not the default for final judgment.
- The verifier cannot be cheaper than the producer: if the mid tier produced, the upper tier verifies. After every agent round that changes code, build and tests run in the main session.
- A "does not exist" claim from the fastest tier is not accepted; a stronger tier verifies it.
- Pass the model explicitly on every agent or workflow call; never leave it empty and fall back to the strongest model.
- At most 3 agents in parallel; discovery and scanning on the fastest tier. Four or more only at the user's explicit request (see `mac-only.md`).

## Claude Code / omp only
- Code writing: a new feature, phase, screen or multi-file implementation is written by a dedicated coding agent on the mid tier at high effort, not by the generic built-in agent on a mid-tier model. Fallback: set the high effort level for that model in the client settings.
- "Quick" requests: code work goes to a coding agent at low effort. The build, test and verifier rules do not change.
- The main session chooses effort per job; an agent cannot change its own effort, it is fixed in its definition. New feature, screen, multi-file or reasoning-heavy work: high-effort coding agent. Small, well-defined single-file work: low-effort coding agent. Listed mechanical fixes: medium-effort agent. If unsure, high. State the choice in one line when starting the agent.
- Model aliases (haiku, sonnet) move to new versions as the client changes; check what an alias resolves to in the installed client version.
- Prompts above about 100K tokens are billed at a premium; in a large repository split scanning folder by folder.

## Second opinions (decided 27 Oct 2026)
- Model tiers: one rule for all clients. The upper tier plans, the coding agent on the mid tier codes, the upper tier reviews against the plan. This replaces the older rule that put the strongest tier in the lead.
- Strongest-tier check: optional, run only when it is worth the cost (for example before a store or beta upload, or on work over 10 files), with the reason stated. Not required.
- Second-model-family check: optional. A read-only agent on another model family reviews the diff (it writes no code) and can run in addition to the upper-tier reviewer on externally visible or over-10-file work, never in place of it. It applies in every client.
- The agent names, versions and the superseded source lines of the user's setup are kept in the private overlay.
