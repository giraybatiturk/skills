---
name: real-grill
description: Grill the user relentlessly about a plan, decision, or idea until nothing is silently assumed. Use when the user wants to stress-test their thinking or says 'grill'. With `--docs`, also writes ADRs and a glossary as decisions settle.
---

> **Local workflow rules:**
> - Measure, don't guess: evidence from the repo and the running system; write "could not measure" when you couldn't.
> - New features go through the `/real-feature-gate` five-heading gate before any code; this skill does not replace that gate.

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for the user's answers before the next round.

Format a round like so:

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.

## `--docs` mode

When invoked as `/real-grill --docs` (or the user asks for documentation as you go), every settled decision leaves a trace before the next round:

- **ADR**: one file per decision in `docs/adr/NNNN-<slug>.md` with Context, Decision, Alternatives considered, Consequences. Numbered in order of settling; never rewrite an accepted ADR, supersede it.
- **Glossary**: `docs/glossary.md`, one line per domain term the interview surfaced, in the user's words. Append, do not reorder.

Write the files as decisions settle, not at the end: an interrupted session still leaves the tree readable. Mention each file you wrote in the round summary.
