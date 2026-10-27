# Metrics, windows and report

This file holds the Measure block, the window rules, the input of `scripts/stats.mjs` and the report. The numbers here are defaults. The numbers in the plan win.

## The Measure block

The block sits in the User story heading of the `real-plan` plan. It has 10 fields.

1. Primary metric and its formula: numerator and denominator.
2. Event and property names.
3. Data source.
4. Baseline: a value, or "read it on the measure date", with its window.
5. Target, labelled "requirement" or "proposal".
6. Guardrails with their limits. Use at most two.
7. Minimum sample, or "default".
8. Wait window and the planned measure date.
9. Release marker: date and time, version or flag.
10. Data owner.

Use at most one secondary metric. Label every result that is not the primary metric "exploratory".

## Windows

- The baseline has the same length as the after window. It ends just before the release.
- Use a multiple of 7 days, so that each window has the same weekday mix. The default is 14 days. The minimum is 7 days.
- Exclude the release day and the ramp-up of a gradual rollout. Exclude incidents and campaigns that the user names.
- A retention metric needs cohort age. The after window ends only when the last cohort has the needed age.
- If the release used a flag with a holdout, compare both groups in the same period. This is better than before and after.
- The earliest measure date is the release date plus the wait window. After new instrumentation ships, the baseline starts again.

## Minimum sample

- A rate needs at least 100 events and 100 non-events in each window.
- A mean or a count per unit needs at least 30 units in each window.
- A sample under the minimum gives the verdict inconclusive.
- The Measure block can set a higher number. Pass it as `min_events` or `min_units`.

## Interval and method

- The interval level is 95%, two-sided.
- A rate uses a two-proportion comparison with an interval for the difference.
- A mean uses a Welch interval.
- A skewed value (for example revenue for each user) uses a bootstrap. The values are anonymous units. Do not show them.
- A before and after result says "associated with". Only a holdout or an experiment can say "effect of".

## Input of `stats.mjs`

Write one JSON file with aggregates. Run `node <skill>/scripts/stats.mjs <input.json>`. Use `-` to read standard input.

```json
{
  "alpha": 0.05,
  "early_look": false,
  "data_health_ok": true,
  "metrics": [
    { "name": "signup_rate", "role": "primary", "kind": "rate", "direction": "up",
      "before": { "num": 200, "den": 4000 }, "after": { "num": 260, "den": 4000 }, "target_abs": 0.01 },
    { "name": "error_rate", "role": "guardrail", "kind": "rate", "direction": "down",
      "before": { "num": 120, "den": 20000 }, "after": { "num": 130, "den": 20000 }, "limit_abs": 0.002 }
  ]
}
```

- `role`: `primary` (exactly one), `guardrail` or `secondary`.
- `kind`: `rate` (`num`, `den`), `mean` (`n`, `mean`, `sd`) or `bootstrap`.
  - For `bootstrap`, `before` and `after` are lists of numbers. `statistic` is `mean` or `median`.
- `direction`: `up` if a higher value is better, `down` if a lower value is better.
- `target_abs` or `target_rel`: the improvement that the plan requires. `target_rel` is a fraction of the before value. Give one of them.
- `limit_abs` or `limit_rel`: for a guardrail, the largest worsening that the plan accepts. A guardrail needs one of them.
- `min_events`, `min_units`, `bootstrap_rounds`, `seed`: optional. The bootstrap uses a fixed seed, so a rerun gives the same interval.
- Exit code 2 means the input is not valid. The message names the field.

The output has one `verdict`, a list of `reasons` and the `first` guardrail to show. Each metric has a `status`, its values, the `change`, the `interval`, the `sample` check and the `improvement` interval. A metric with a sample under the minimum lists the `shortfall`. An inconclusive primary metric can have `sample_factor_to_resolve`. It is a rough multiple of the current sample, and it assumes that the estimate stays the same.

Metric status:
- Primary: `hit`, `miss`, `inconclusive`, `small-sample` or `empty-window`.
- Guardrail: `ok`, `possible-breach`, `breached`, `unknown` (small sample) or `empty-window`.
  - `possible-breach`: the estimate is past the limit, but the interval is not.
  - `breached`: the whole interval is past the limit.

Verdict rules, in this order:
1. A breached guardrail gives miss.
2. Otherwise the primary status gives hit, miss or inconclusive.
3. A hit needs every guardrail to be `ok`. Otherwise the verdict is inconclusive.
4. `data_health_ok: false` gives inconclusive.
5. `early_look: true` gives inconclusive. The report still shows a breached guardrail first.

## Report file

- Path: `docs/measure/YYYY-MM-DD-<slug>.md`, or the reports folder of the project.
- Sections, in this order:
  1. Verdict and next action.
  2. Release record: what shipped, when, how.
  3. Metric table: metric, role, definition, baseline, after, change, interval, sample, status.
  4. Windows and data health.
  5. Guardrails.
  6. Limits: confounders, wording of cause, **Could not measure**, unverified items.
  7. Evidence: each query with its source and time.
  8. Decision record: the user adds the decision and the date.
- The report has no person-level row, key or token.

## Chat message

1. The verdict.
2. Up to five important items. A guardrail result comes first.
3. The link to the report.
4. One next action.
