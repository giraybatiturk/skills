---
name: real-measure
description: "Judge a shipped change with live data: did it work, ölçüm, çalıştı mı, release result, before and after, A/B outcome. Reads the Measure block of the real-plan plan, queries analytics through a connected tool, an API or an export file, and gives a verdict (hit, miss or inconclusive) with intervals, sample sizes and one next action. Read-only. Use after release. Do not use before release (real-test, real-audit). (v0.14.0)"
license: MIT
metadata:
  author: Giray Batıtürk
  version: 0.14.0
  source: https://github.com/giraybatiturk/skills
---

# Real measure

Use this workflow after a release. It checks with live data if a shipped change hit its goal. It compares the result with the acceptance criteria and the success metrics of the `real-plan` plan.

The skill is read-only. It runs on the machine of the user. It changes no code, flag, analytics setup or release.

`<skill>` below means the folder that contains this `SKILL.md`. Resolve it from the skill catalog of your tool.

Not the other skills.
- `real-audit` gives expert judgment before and without live outcome data. It defines the metric tree. This skill reads the metrics.
- `real-test` runs flow tests in a test or staging app before release. A green test is not an outcome.
- `real-research` finds external facts. This skill reads internal data of the product only.
- `real-brainstorm` generates options. This skill gives it evidence.
- `real-check` scans a public URL once. It does not overlap with this skill.

## Rules

- Use aggregates only. Every query returns counts, rates or means. Show no person-level row, key or token in chat or in the report.
- Use a read-only key. Never ask for a write key. Never read `.env*` files. Take the key from the tool connection or from an environment variable.
- Never query an event that you guessed. If the event is missing, report **Could not measure** and stop.
- Never do the arithmetic yourself. Run `<skill>/scripts/stats.mjs`.
- Use one primary metric and one window that the plan set before the run. Do not look at more windows to find a better result. Label each other result "exploratory".
- Say "associated with" for a before and after result. Say "effect of" only for a holdout or an experiment.
- Make no write call. Do not create a saved insight or a dashboard, unless the user asks.
- Execute no next action. The user decides.

## Steps

1. **Parse `$ARGUMENTS`.** Required: a plan file or a slug. Otherwise show `/real-measure <plan file or slug> [--window DAYS] [--baseline-from DATE --baseline-to DATE] [--source mcp|api|file PATH] [--out DIR] [--lang tr|en]` and stop.
   - Find the plan in `docs/plans/`. Find `PRODUCT.md` and the Source field of the plan.
   - The default language is English. Use Turkish only with `--lang tr` or when the user asks.
2. **Read the Measure block.** The block is in the User story heading of the plan. Its fields are in `references/metrics.md`.
   - If the plan has criteria but no Measure block, propose metrics. Label them "proposal". Wait for the approval of the user before you run any query.
   - If the plan has no Measure block because it has no outcome goal, tell the user. Offer one `real-plan` question: what success looks like.
   - If the release record is missing, ask one question: when, and by which version or flag.
3. **Find the data source.** Read `references/sources.md`. Use this order: a connected analytics tool, the HTTP API with a read-only key, an export file.
   - Ask at most 3 questions. Ask only what you cannot find.
4. **Check the data.** Run the data-health checks of `references/sources.md` first.
   - If an event or a property is missing, report **Could not measure**. List the missing events with this table: event name, properties, trigger, owner. The next action is: instrument first, in `real-plan` Backend scope. Stop.
   - A window with zero events is a data-health finding. It is not a miss.
5. **Set the windows.** The baseline has the same length as the after window and ends just before the release. Use the numbers of the plan. Defaults are in `references/metrics.md`.
   - A run before the planned measure date is an "early look". Its verdict is capped at inconclusive.
6. **Query.** Query only what the Measure block names. Use the limits of `references/sources.md` (20 queries, one timeout).
   - A query error or a timeout gives **Could not measure**. It never gives a guess.
7. **Compute.** Write the aggregates in the input format of `references/metrics.md`. Run `node <skill>/scripts/stats.mjs <input.json>`.
   - Use the verdict, the intervals and the sample checks of the output as they are.
8. **Report.** Write the report file and the chat message that `references/metrics.md` defines.
   - Give the verdict first. A guardrail result that is breached or possible comes before everything else.
   - Give exactly one next action: keep, iterate, roll back or back to brainstorm.
   - End with one handoff line: `real-plan` for iterate, `real-brainstorm` for back to brainstorm.

## Verdicts

- **Hit:** all of these are true.
  - The primary metric moved in the target direction.
  - The interval excludes zero.
  - The estimate reaches the target.
  - No guardrail broke.
  - The sample minimum is met and the data health is good.
- **Miss:** one of these is true.
  - The upper end of the interval is below the target.
  - The metric moved the wrong way, and the interval excludes zero.
  - A guardrail crossed its limit.
- **Inconclusive:** every other case.
  - This includes a small sample, a short window, a data-health problem and an early look.
  - It also includes an interval that holds both zero and the target.
- **Could not measure** is a status. It is not a verdict.

## Next action

| Result | Next action |
|---|---|
| Hit | Keep. Close the plan. Record the result. |
| Inconclusive | Keep, and measure again. Name the date and the extra sample that is needed. |
| Miss, the cause is in the change | Iterate. Go back to `real-plan` with the new facts. |
| Miss with harm or a guardrail break | Roll back. Recommend it. The user does it. |
| Miss and the goal or the need looks wrong | Back to brainstorm. Give the evidence to `real-brainstorm`. |

## Safety

- Personal data stays in the source. The skill adds no telemetry.
- The report holds real numbers of a product. Keep the report out of a public repo. Publish only aggregates that the owner approved.
- This workflow needs `real-plan` (the Measure block) and `real-audit` (the metric-tree rule) from the same bundle. If one is missing, report the missing dependency. Ask the user to install the full Real bundle.
