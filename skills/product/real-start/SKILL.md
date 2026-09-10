---
name: real-start
description: Entry point for this skill set. Asks where you are in the work, then names the exact command to run. Give it the task directly and it answers without asking.
disable-model-invocation: true
---

# /real-start

This file routes; it never does the work itself.

**Four of the skills this file routes to carry `disable-model-invocation: true`** - the model cannot launch them, only you can. So the output is always **the command for you to type**, on its own line, ready to copy. Never replicate a target skill's workflow inline; that is the failure this file exists to prevent.

The two routed skills without the flag (`real-grill`, `real-research`) may be loaded directly with the `Skill` tool instead of printed. (`real-design-rules` has no flag either, but this file never routes to it.)

**Print the form that matches the install.** Symlinked into `~/.claude/skills/`, the bare `/real-module-audit` works. Installed as a plugin, Claude Code namespaces every skill and only `/giraybatiturk-skills:real-module-audit` works. Check which one this session has and print that form.

## With an argument: answer, don't ask

`/real-start audit the messaging module` → name the skill, one line of reasoning, then the command:

```
/real-module-audit messaging
```

If the argument clearly lands in the audit branch but doesn't say **which** audit (module, screen or speed), ask only the second question below. Don't re-ask the first.

If the argument matches nothing in this set, say so and carry on normally - don't force it onto the map and don't fall back to the question.

## With no argument: ask once

Use `AskUserQuestion`, one question, four options:

| Option | Description shown | Answer |
|---|---|---|
| Building something new | No code yet. Intent, scenarios and scope come first. | `/real-feature-gate` |
| Sharpening an idea | A decision or plan exists but hasn't settled. | load `real-grill` |
| Done, let's audit | A working module, screen or release candidate. | second question below |
| Need a fact | The basis for a decision isn't in the repo: docs, API, third party. | load `real-research` |

`AskUserQuestion` always adds an "Other" option. If the user writes something there, don't force it onto the map: say "this set has no match for that, carrying on normally" and continue as usual.

## Second question, audit branch only

This is the only place a second question is allowed. Never a third.

| Option | Description shown | Answer |
|---|---|---|
| Module | Missing-scenario hunt: permissions, error paths, empty states. | `/real-module-audit` |
| Screen | One screen against DESIGN.md, scored across 9 dimensions. | `/real-design-audit` |
| Speed | Bundle and load, measured against a budget. | `/real-perf-audit` |
| All three | Full pre-release pass. | print all three, in order |

For "all three", print the commands as a numbered list and say to run them one at a time, letting each finish before the next: they each need their own context, and a finding in the module audit can change what the screen audit should look at.

## Arguments the target needs

`real-feature-gate` wants the feature, `real-module-audit` a module name, `real-design-audit` a screen name, `real-perf-audit` a target. If the user hasn't said it, include a placeholder in the printed command (`/real-module-audit <module>`) and say what goes there. Don't ask for it as another question.

## The flow

```
idea      real-grill              interview until nothing is silently assumed
gate      /real-feature-gate      five headings, eight scenario classes, approval; no code yet
build     your own flow           Claude Code's /code-review, TDD and debugging skills
audit     /real-module-audit → /real-design-audit → /real-perf-audit
```

Idea and gate stay in one context window. A fact you need on the way: `real-research`. Any UI work picks up `real-design-rules` on its own; never route to it.

## The set

| Skill | When | Invoked by |
|---|---|---|
| [real-grill](../../engineering/real-grill/SKILL.md) | Sharpen a plan or decision | model |
| [real-feature-gate](../real-feature-gate/SKILL.md) | Before writing code | you |
| [real-module-audit](../real-module-audit/SKILL.md) | Missing scenarios in a built module | you |
| [real-design-audit](../../design/real-design-audit/SKILL.md) | Screen is done | you |
| [real-design-rules](../../design/real-design-rules/SKILL.md) | Any UI work | model |
| [real-perf-audit](../real-perf-audit/SKILL.md) | Dependency added, before release | you |
| [real-research](../../engineering/real-research/SKILL.md) | Primary-source research | model |

"you" = `disable-model-invocation: true`; runs only when you type it. "model" = picked up when the topic matches.
