# Skills for Real AI Product Leads

Eight skills for the part of the job an engineering-only workflow leaves to production to discover.

The premise: when an AI agent writes code, the bottleneck stops being typing speed and becomes **knowing what to ask for**. The happy path gets built quickly and well. What stays missing is the permission state nobody named, the error path nobody wrote down, the empty screen nobody drew. These skills exist to surface those before the code, and to find them after.

Built on measurement rather than guesswork: every skill reads the repo and the running system, and writes "could not measure" when it couldn't.

Live listing: [giraybatiturk.com/skills](https://giraybatiturk.com/skills)

---

## Why this exists

A measured case, from a messaging module: **10 of 21 scenarios were missing**, and the user found nearly all of them in production. The unread badge never went down. One of eight permission actions was implemented. The error text showed a raw backend code.

None of that is visible on the happy path. None of it is a coding mistake either; it's a **specification** gap. The agent built exactly what it was asked for.

So the flow here puts two gates around the coding, and neither of them writes code:

- **Before**: `/real-feature-gate` forces the scenario list out into the open and blocks on approval.
- **After**: three audits (`module`, `design`, `perf`) measure what actually shipped against what was meant to ship.

The middle, the coding itself, is deliberately empty. Claude Code's own `/code-review`, TDD and debugging skills cover it, and a duplicate would only drift.

---

## Install

**Option A, plugin** (updates arrive automatically):

```
/plugin marketplace add giraybatiturk/skills
/plugin install giraybatiturk-skills@giraybatiturk
```

Claude Code namespaces plugin skills, so you type `/giraybatiturk-skills:real-grill`.

**Option B, symlink** (short `/real-grill` form, edits take effect immediately):

```bash
git clone https://github.com/giraybatiturk/skills ~/Developer/skills
mkdir -p ~/.claude/skills
for d in ~/Developer/skills/skills/*/real-*; do
  ln -sfn "$d" ~/.claude/skills/$(basename "$d")
done
```

Pick one. Running both lists every skill twice.

**Codex and other agents:**

```bash
npx skills@latest add giraybatiturk/skills
```

Verify: open a new session and type `/real-`. Eight entries should appear. If not, `/reload-skills`.

---

## Where do I start?

Type `/real-start`. It asks one question, then names the exact command to run.

```
/real-start
→ Building something new?  Sharpening an idea?  Done, let's audit?  Need a fact?
```

Give it the task and it skips the question: `/real-start audit the messaging module` answers with `/real-module-audit messaging`.

It prints commands rather than launching them, on purpose: four of the skills it routes to carry `disable-model-invocation: true`, so only you can start them. A router that pretended otherwise would silently rewrite their workflow instead of running it.

---

## The route

```
idea    /real-grill            interview until nothing is silently assumed
gate    /real-feature-gate     five headings, eight scenario classes, approval; no code yet
build   your own flow          Claude Code's /code-review, TDD and debugging skills
audit   /real-module-audit → /real-design-audit → /real-perf-audit
```

Idea and gate stay in **one context window**: the gate's output is only as good as the interview that fed it. Each audit starts fresh.

---

## The skills

### `/real-start` · you type it

**What it does.** Asks where you are in the work, names the command to run. A second question only in the audit branch, never a third.

**When you need it.** When you know something is off but not which tool fits. Also useful when you haven't opened the set in weeks.

**How to start.** `/real-start`, or `/real-start <your task>` to skip the question.

---

### `/real-feature-gate` · you type it

**What it does.** Runs *before* any code for a new feature. Five headings, approved by you before a single file is opened:

1. **Analysis**: what's being asked, what exists today, where the gap is. Measured from the repo, not guessed.
2. **User stories** with acceptance tests, in the user's own words
3. **Backend scope**: endpoints, fields, permissions, error codes. Existing or new.
4. **Frontend scope**: screens, states (empty / loading / error), copy, languages, variants.
5. **Wiring**: where the two meet. Address, body, headers, CORS, timeouts, build constraints.

It also walks **eight scenario classes** that the happy path hides: permissions, state transitions, error paths, empty states, multi-user, third parties, contract consistency, deployment.

**When you need it.** Any new feature or module. Any time you're about to say "this is simple, let's just build it" - that sentence is the trigger.

**Common question: doesn't this slow me down?** It shortens when you ask it to; it doesn't get skipped. The measured alternative is ten missing scenarios found by users, each becoming its own round.

**How to start.** `/real-feature-gate media support for messaging`

---

### `/real-module-audit` · you type it

**What it does.** Takes a module that already exists and hunts for missing scenarios. Inventories endpoints, permissions and error codes **from the code**, then outputs a permission matrix and a release order.

**When you need it.**

- Touching a module for the **second time** (adding on top, not building fresh)
- The moment a bug is found: *what else in the same class is broken?*
- Before going live, while it works in test but hasn't reached a customer
- Returning to a module nobody touched for a while

**Common question: how is this different from the gate?** Same eight scenario classes, opposite direction: the gate produces a plan for code not yet written, this produces a gap list for code that exists.

**How to start.** `/real-module-audit messaging`

---

### `/real-design-audit` · you type it

**What it does.** Audits one screen against the project's `DESIGN.md`, from a **screenshot plus the code**, scored across nine dimensions: token/colour, i18n, component, layout, elevation/motion, accessibility, state matrix, language + IA, consistency.

Starts from the render, not the source. Spacing, alignment, rhythm and state only show in the picture; static code misses them. It opens every hidden container too, accordions, dropdowns, modals, because that's where the unaudited screens hide.

Findings carry `file:line`, severity (P0-P3) and the DESIGN.md section violated. It never invents a rule; if the project has no `DESIGN.md`, `real-design-rules` is the baseline.

**When you need it.** A screen is done and you're about to call it done.

**Common question: what if I don't have a DESIGN.md?** Then the baseline applies and the audit still runs. Writing one afterwards from the measured values is usually the better next step.

**How to start.** `/real-design-audit VoucherEntryScreen`, with a screenshot in the conversation.

---

### `/real-perf-audit` · you type it

**What it does.** Measures bundle and load performance against a budget, finds where an overrun comes from, and applies the fix. Measures the **build output**, not the source: reading the source and concluding "preload is missing" turns out wrong often enough to be a rule.

Default budget: first load ≤ 220 KB gzip. If the project's `DESIGN.md` names a budget, that wins.

**When you need it.** A new dependency was added (the most common source of overruns), a heavy screen or chart landed, before going live, or someone says "it got slow".

**How to start.** `/real-perf-audit` - with no argument it measures every app in the project.

---

### `real-grill` · the model loads it

**What it does.** Interviews you until nothing is left silently assumed. Maps the decisions as a tree, asks the whole frontier in one round, waits for your answers, recomputes. Facts are its job (it dispatches sub-agents); decisions are yours.

With `--docs`, every settled decision leaves an ADR in `docs/adr/` and a glossary line, written as they settle rather than at the end.

**When you need it.** A plan or decision exists but hasn't set, and the next step would otherwise be guessing.

**Common question: why isn't this a slash command?** It is one, but it also fires on its own when you say "grill me" or the conversation is clearly a design argument.

---

### `real-design-rules` · the model loads it

**What it does.** The binding baseline for any UI work: token discipline, forms, states, accessibility, UX writing. Thirteen sections, 53 rules.

**When you need it.** You don't call it; it loads itself whenever a screen, component or form is in play.

**Precedence.** The project's own `DESIGN.md` outranks it. This is the floor, not the ceiling.

---

### `real-research` · the model loads it

**What it does.** Investigates a question against high-trust primary sources and writes the findings to a Markdown file in the repo, with a citation per claim.

**When you need it.** The basis for a decision isn't in the repo: third-party behaviour, an API contract, a pricing table, a provider limit.

**Why it writes to a file.** So the next session can read it instead of re-searching, and so the citations survive the conversation.

---

## What's deliberately not here

No TDD skill, no code-review skill, no debugger. Claude Code ships those and the `superpowers` set covers the rest. A second copy would drift from the first, and the drift is worse than the gap.

Version 0.5.0 cut the set from 19 to 7. Three went because Claude Code already covered them; the rest were an issue-tracker pipeline that read well and was never run once on a solo project, plus a map that seven skills didn't need.

---

## Project dependencies

The audits treat the project's `DESIGN.md` as the source of rules; without one, `real-design-rules` is the baseline. `real-module-audit` also reads `AGENTS.md`/`CLAUDE.md`, but for where things live, not for rules. `/real-grill --docs` writes to `docs/adr/` and `docs/glossary.md`.

`/real-grill` and `/real-research` are adapted from the upstream workflow (MIT). The gate and the three audits are original.

## Cost

All eight descriptions together add **~420 tokens** to a session, whether you use them or not. A skill's full text loads only when it runs: 300 tokens for the smallest (`real-research`), 2,200 for the largest (`real-module-audit`).

## Changelog

- **0.6.0** (2026-09-10): `/real-start` back as an interactive entry point. Asks one question (a second only in the audit branch) and names the command to run. It prints commands rather than launching them: four of the routed skills carry `disable-model-invocation`, so the model cannot launch them, and a router that pretends otherwise silently replicates their workflow instead.
- **0.5.0** (2026-09-09): 19 → 7. Dropped what Claude Code or the superpowers set already provides (`tdd`, `code-review`, `diagnosing-bugs`) and the issue-tracker pipeline nobody ran solo (`setup`, `to-spec`, `to-tickets`, `implement`, `triage`), plus `start` (no map needed for seven) and `prototype`. `grilling` + `grill-me` + `grill-with-docs` merged into `real-grill` with a `--docs` mode. Breaking: the removed names stop working.
- **0.4.0** (2026-09-09): every skill prefixed `real-`; fixes a name clash with other skill sets. Breaking: old names stop working.
- **0.3.0** (2026-09-07): English throughout; folders `product/`, `design/`, `engineering/`.
- **0.2.0** (2026-09-07): 13 skills from the upstream workflow under the engineering flow; MIT.
- **0.1.0** (2026-09-07): first set, 6 skills.
