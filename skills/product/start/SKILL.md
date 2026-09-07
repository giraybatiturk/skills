---
name: start
description: Entry point and map of every skill in this set. Ask it which skill fits your situation, or give it the task and it picks and runs the right one.
disable-model-invocation: true
---

# /start

Called with no argument: **ask, then run.** Called with an argument: go straight to the work. If the user already said what they want (e.g. `/start audit the messaging module`), don't ask; pick the skill and say so: "Running `/module-audit`."

## The main flow: idea → shipped

```
idea       /grill-with-docs      sharpen the idea by interview; leaves CONTEXT.md + ADRs
gate       /feature-gate         five headings, eight scenario classes, approval; no code yet
plan       /to-spec → /to-tickets   for multi-session work; single-session goes straight to /implement
build      /implement            drives /tdd (one slice at a time) and /code-review (standards + spec)
audit      /module-audit → /design-audit → /perf-audit
```

Context rule: idea, gate and plan stay in **one context window**; no compact or clear until `/to-tickets` is done. Each `/implement` starts fresh from its ticket.

If a question can't be settled in conversation (a state model, a UI you have to see): `/prototype` answers it with throwaway code and the answer folds back in.

## On-ramps

- **Bugs and requests piling up** → `/triage`. Only for issues you didn't write; never triage `/to-tickets` output.
- **Something's broken** → `/diagnosing-bugs`. A red feedback loop first, theories second. Once fixed, `/module-audit`: **what else in the same class is broken?**
- **New dependency added / "it got slow"** → `/perf-audit`.
- **"How does the screen look?"** → `/design-audit`.
- **"We're shipping"** → `/module-audit`, `/design-audit`, `/perf-audit`, in that order.
- **No repo, just an idea** → `/grill-me` (stateless interview).
- **Need facts from docs or an API** → `/research`, as a background agent.

## First-time setup

Once per repo: `/setup`. Picks the issue tracker (GitHub / GitLab / local markdown), triage labels, and the `CONTEXT.md` + ADR layout. `/to-tickets`, `/triage` and `/to-spec` read from it.

## Table

| Skill | When | Invoked by |
|---|---|---|
| `/setup` | Once per repo | you |
| `/grill-with-docs` · `/grill-me` | Sharpen the idea | you |
| `/feature-gate` | Before writing code | you |
| `/to-spec` · `/to-tickets` | Multi-session plan | you |
| `/implement` | Build a ticket | you |
| `/triage` | Incoming issue pile | you |
| `/module-audit` | Missing scenarios in a built module | you |
| `/design-audit` | Screen is done | you |
| `/perf-audit` | Dependency added, before release | you |
| `tdd` · `code-review` · `diagnosing-bugs` · `prototype` · `research` · `grilling` · `design-rules` | When the topic matches | model |

If you'd route to a skill that isn't installed, say "not installed" and continue with the rest of the flow.

## Project-specific commands

If the project has its own commands (`.claude/commands/`, a table in `AGENTS.md`), list them in the same question. Release flows, backend-request templates and the like live in the project repo, not here.
