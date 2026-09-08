---
name: real-start
description: Entry point and map of every skill in this set. Ask it which skill fits your situation, or give it the task and it picks and runs the right one.
disable-model-invocation: true
---

# /real-start

Called with no argument: **ask, then run.** Called with an argument: go straight to the work. If the user already said what they want (e.g. `/real-start audit the messaging module`), don't ask; pick the skill and say so: "Running `/real-module-audit`."

## The main flow: idea → shipped

```
idea       /real-grill-with-docs      sharpen the idea by interview; leaves CONTEXT.md + ADRs
gate       /real-feature-gate         five headings, eight scenario classes, approval; no code yet
plan       /real-to-spec → /real-to-tickets   for multi-session work; single-session goes straight to /real-implement
build      /real-implement            drives /real-tdd (one slice at a time) and /real-code-review (standards + spec)
audit      /real-module-audit → /real-design-audit → /real-perf-audit
```

Context rule: idea, gate and plan stay in **one context window**; no compact or clear until `/real-to-tickets` is done. Each `/real-implement` starts fresh from its ticket.

If a question can't be settled in conversation (a state model, a UI you have to see): `/real-prototype` answers it with throwaway code and the answer folds back in.

## On-ramps

- **Bugs and requests piling up** → `/real-triage`. Only for issues you didn't write; never triage `/real-to-tickets` output.
- **Something's broken** → `/real-diagnosing-bugs`. A red feedback loop first, theories second. Once fixed, `/real-module-audit`: **what else in the same class is broken?**
- **New dependency added / "it got slow"** → `/real-perf-audit`.
- **"How does the screen look?"** → `/real-design-audit`.
- **"We're shipping"** → `/real-module-audit`, `/real-design-audit`, `/real-perf-audit`, in that order.
- **No repo, just an idea** → `/real-grill-me` (stateless interview).
- **Need facts from docs or an API** → `/real-research`, as a background agent.

## First-time setup

Once per repo: `/real-setup`. Picks the issue tracker (GitHub / GitLab / local markdown), triage labels, and the `CONTEXT.md` + ADR layout. `/real-to-tickets`, `/real-triage` and `/real-to-spec` read from it.

## Table

| Skill | When | Invoked by |
|---|---|---|
| `/real-setup` | Once per repo | you |
| `/real-grill-with-docs` · `/real-grill-me` | Sharpen the idea | you |
| `/real-feature-gate` | Before writing code | you |
| `/real-to-spec` · `/real-to-tickets` | Multi-session plan | you |
| `/real-implement` | Build a ticket | you |
| `/real-triage` | Incoming issue pile | you |
| `/real-module-audit` | Missing scenarios in a built module | you |
| `/real-design-audit` | Screen is done | you |
| `/real-perf-audit` | Dependency added, before release | you |
| `tdd` · `code-review` · `diagnosing-bugs` · `prototype` · `research` · `grilling` · `design-rules` | When the topic matches | model |

If you'd route to a skill that isn't installed, say "not installed" and continue with the rest of the flow.

## Project-specific commands

If the project has its own commands (`.claude/commands/`, a table in `AGENTS.md`), list them in the same question. Release flows, backend-request templates and the like live in the project repo, not here.
