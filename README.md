# Skills for Real AI Product Leads

The skills I run every day as an AI product lead who also ships: sharpen the idea, gate it before any code, split it into spec and tickets, test first, then audit the module, the screen and the bundle. Small, composable, built on measurement rather than guesswork.

The engineering flow is adapted from the upstream workflow (MIT). The product gate and the audits are what I added on top: the parts an engineering-only flow leaves to production to discover.

Live listing: [giraybatiturk.com/skills](https://giraybatiturk.com/skills)

## Install

Claude Code, as a plugin (updates arrive automatically):

```
/plugin marketplace add giraybatiturk/skills
/plugin install giraybatiturk-skills@giraybatiturk
```

Codex and other agents, or an editable copy you own:

```bash
npx skills@latest add giraybatiturk/skills
```

## First run

Two commands, in this order:

```
/real-start      the map: what each skill does and which one fits your situation
/real-setup      once per repo: issue tracker, triage labels, domain-doc layout
```

`/real-start` also takes the task directly, e.g. `/real-start audit the messaging module`, and picks the right skill for you.

Every skill in this set is prefixed `real-`, so typing `/real-` lists them all.

## Get oriented

Don't know where to begin? `/real-start` is the map. The main route most work travels:

```
idea       /real-grill-with-docs      sharpen the idea by interview; leaves CONTEXT.md + ADRs
gate       /real-feature-gate         five headings, eight scenario classes, approval; no code yet
plan       /real-to-spec → /real-to-tickets   for multi-session work; single-session goes straight to /real-implement
build      /real-implement            drives /real-tdd and /real-code-review
audit      /real-module-audit → /real-design-audit → /real-perf-audit
```

Idea, gate and plan stay in one context window; no compact or clear until `/real-to-tickets` is done. Each `/real-implement` starts fresh from its ticket.

On-ramps: a pile of incoming issues → `/real-triage`; something broken → `/real-diagnosing-bugs`, then `/real-module-audit` to find its siblings; a question that needs running code → `/real-prototype`.

## Featured

- **`/real-feature-gate`**: before writing code. Intent, measurement, eight scenario classes (permissions, state transitions, error paths, empty states, multi-user, third parties, contract consistency, deployment), five scope headings, approval gate.
- **`/real-module-audit`**: the missing-scenario hunt in a module that already exists. Inventories endpoints, permissions and error codes from the code; outputs a permission matrix and a release order.
- **`/real-design-audit`**: one screen against the project's DESIGN.md, from a screenshot plus the code, scored across nine dimensions.
- **`/real-grill-with-docs`**: the relentless interview that sharpens an idea and leaves a domain model behind.
- **`/real-tdd`**: red-green-refactor, one vertical slice at a time.

## The skill set

### Product gate and audits (`skills/product`)

| Skill | When | Invoked by |
|---|---|---|
| [start](./skills/product/start/SKILL.md) | You don't know which one | you |
| [feature-gate](./skills/product/feature-gate/SKILL.md) | Before writing code | you |
| [module-audit](./skills/product/module-audit/SKILL.md) | Missing scenarios in a built module | you |
| [perf-audit](./skills/product/perf-audit/SKILL.md) | Dependency added, before release | you |

### Design (`skills/design`)

| Skill | When | Invoked by |
|---|---|---|
| [design-audit](./skills/design/design-audit/SKILL.md) | Screen is done; DESIGN.md check | you |
| [design-rules](./skills/design/design-rules/SKILL.md) | Any UI work | model |

### Engineering flow (`skills/engineering`, adapted from the upstream workflow)

| Skill | When | Invoked by |
|---|---|---|
| [setup](./skills/engineering/setup/SKILL.md) | Once per repo: tracker, labels, doc layout | you |
| [grill-with-docs](./skills/engineering/grill-with-docs/SKILL.md) | Sharpen the idea, inside a repo | you |
| [grill-me](./skills/engineering/grill-me/SKILL.md) | Same interview, no repo | you |
| [to-spec](./skills/engineering/to-spec/SKILL.md) | Turn the conversation into a spec | you |
| [to-tickets](./skills/engineering/to-tickets/SKILL.md) | Split a spec into tickets with blocking edges | you |
| [implement](./skills/engineering/implement/SKILL.md) | Build a ticket, with tdd + code-review inside | you |
| [triage](./skills/engineering/triage/SKILL.md) | Move incoming issues through triage roles | you |
| [grilling](./skills/engineering/grilling/SKILL.md) | The interview primitive the others call | model |
| [tdd](./skills/engineering/tdd/SKILL.md) | Test first, slice by slice | model |
| [code-review](./skills/engineering/code-review/SKILL.md) | Two-axis review of a diff: standards + spec | model |
| [diagnosing-bugs](./skills/engineering/diagnosing-bugs/SKILL.md) | Hard bugs: a red loop first, theories second | model |
| [prototype](./skills/engineering/prototype/SKILL.md) | Throwaway code that answers one question | model |
| [research](./skills/engineering/research/SKILL.md) | Primary-source research, written to a file | model |

"you" = `disable-model-invocation: true`; runs only when you type `/name`. "model" = picked up when the topic matches.

## Project dependencies

The audits treat the project's `DESIGN.md` and `AGENTS.md`/`CLAUDE.md` as the source of rules; without a `DESIGN.md`, `design-rules` is the baseline. The engineering skills read `docs/agents/`, which `/real-setup` writes.

## Changelog

- **0.4.0** (2026-09-09): every skill prefixed `real-` (`/real-tdd`, `/real-feature-gate`); fixes a name clash with other skill sets and groups the set under one `/real-` prefix. Breaking: old names stop working.
- **0.3.0** (2026-09-07): English throughout. Skills renamed (`start`, `feature-gate`, `module-audit`, `perf-audit`, `design-audit`, `design-rules`); folders `product/`, `design/`, `engineering/`. README in the shape of a skills page: install, get oriented, featured, the set.
- **0.2.0** (2026-09-07): 13 skills from the upstream workflow under the engineering flow, each with an adaptation block; `start` replaces `start`; `setup` replaces `setup`; MIT.
- **0.1.0** (2026-09-07): first set, 6 skills.
