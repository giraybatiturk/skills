# Skills for Real AI Product Leads

Eight skills I run every day as an AI product lead who also ships: sharpen the idea, gate it before any code, then audit the module, the screen and the bundle. Small, composable, built on measurement rather than guesswork.

`/real-grill` and `/real-research` are adapted from the upstream workflow (MIT). The gate and the audits are what I added on top: the parts an engineering-only flow leaves to production to discover.

Live listing: [giraybatiturk.com/skills](https://giraybatiturk.com/skills)

## Install

Claude Code, as a plugin (updates arrive automatically):

```
/plugin marketplace add giraybatiturk/skills
/plugin install giraybatiturk-skills@giraybatiturk
```

Plugin skills are namespaced by Claude Code: `/giraybatiturk-skills:real-grill`. For the short `/real-grill` form, link the skill folders into `~/.claude/skills/` instead:

```bash
git clone https://github.com/giraybatiturk/skills ~/Developer/skills
for d in ~/Developer/skills/skills/*/real-*; do ln -sfn "$d" ~/.claude/skills/$(basename "$d"); done
```

Codex and other agents:

```bash
npx skills@latest add giraybatiturk/skills
```

## The route

Don't know where to start? `/real-start` asks one question and names the command to run.

```
idea    /real-grill            interview until nothing is silently assumed; --docs leaves ADRs + glossary
gate    /real-feature-gate     five headings, eight scenario classes, approval; no code yet
build   your own flow          Claude Code's /code-review, TDD and debugging skills already cover it
audit   /real-module-audit → /real-design-audit → /real-perf-audit
```

Idea and gate stay in one context window. A fact you need on the way → `/real-research`. Any UI work picks up `real-design-rules` on its own.

## The skill set

| Skill | When | Invoked by |
|---|---|---|
| [real-start](./skills/product/real-start/SKILL.md) | You don't know which one | you |
| [real-grill](./skills/engineering/real-grill/SKILL.md) | Sharpen a plan or decision by relentless interview | model |
| [real-feature-gate](./skills/product/real-feature-gate/SKILL.md) | Before writing code | you |
| [real-module-audit](./skills/product/real-module-audit/SKILL.md) | Missing scenarios in a built module | you |
| [real-design-audit](./skills/design/real-design-audit/SKILL.md) | Screen is done; DESIGN.md check | you |
| [real-design-rules](./skills/design/real-design-rules/SKILL.md) | Any UI work | model |
| [real-perf-audit](./skills/product/real-perf-audit/SKILL.md) | Dependency added, before release | you |
| [real-research](./skills/engineering/real-research/SKILL.md) | Primary-source research, written to a file | model |

"you" = `disable-model-invocation: true`; runs only when you type `/name`. "model" = picked up when the topic matches.

## Project dependencies

The audits treat the project's `DESIGN.md` and `AGENTS.md`/`CLAUDE.md` as the source of rules; without a `DESIGN.md`, `real-design-rules` is the baseline. `/real-grill --docs` writes to `docs/adr/` and `docs/glossary.md`.

## Changelog

- **0.6.0** (2026-09-10): `/real-start` back as an interactive entry point. Asks one question (a second only in the audit branch) and names the command to run. It prints commands rather than launching them: four of the routed skills carry `disable-model-invocation`, so the model cannot launch them, and a router that pretends otherwise silently replicates their workflow instead.
- **0.5.0** (2026-09-09): 19 → 7. Dropped what Claude Code or the superpowers set already provides (`tdd`, `code-review`, `diagnosing-bugs`) and the issue-tracker pipeline nobody ran solo (`setup`, `to-spec`, `to-tickets`, `implement`, `triage`), plus `start` (no map needed for seven) and `prototype`. `grilling` + `grill-me` + `grill-with-docs` merged into `real-grill` with a `--docs` mode. Breaking: the removed names stop working.
- **0.4.0** (2026-09-09): every skill prefixed `real-`; fixes a name clash with other skill sets. Breaking: old names stop working.
- **0.3.0** (2026-09-07): English throughout; folders `product/`, `design/`, `engineering/`.
- **0.2.0** (2026-09-07): 13 skills from the upstream workflow under the engineering flow; MIT.
- **0.1.0** (2026-09-07): first set, 6 skills.
