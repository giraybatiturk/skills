# Data sources and queries

## Order of sources

1. An analytics tool that is connected to your tool, for example a PostHog server. Use its query tools. Read experiments and flags only to find the rollout split.
2. The HTTP API of the analytics tool. Use a read-only key from an environment variable. Never read `.env*` files.
3. An export file (CSV or JSON) that the user gives. It holds aggregates only. This works with any analytics tool.
4. Logs and service metrics, for example error rate and latency. They are mostly guardrail metrics. In v1, the user gives them as an export file.
5. Store metrics, for example downloads, ratings and subscription counts. In v1, the user gives them as an export file. The skill never logs in to a store.

Find what exists first: `PRODUCT.md`, the Source field of the plan and the tools of your tool. Ask at most 3 questions.

## What to query

- Only what the Measure block names: one primary metric, up to two guardrails and up to one secondary metric.
- The segment splits that the plan names.
- The release marker: date and time, and version or flag.
- Ask for aggregates only. Use at most 20 queries and one timeout for each query.
- Make no write call. Do not create a saved insight or a dashboard, unless the user asks.

## Data-health checks

Run these before the metric queries.
- Events for each day in both windows. A gap or a drop to zero is a tracking problem.
- The environment filter: production, not staging. Show the filter in the report.
- The test-user filter and automated traffic.
- Each event name and property of the Measure block exists in the source.

## When there is no instrumentation

- Signs: no event, a missing property, zero volume in the baseline, or a gap in the daily volume.
- Stop. Run no query on a guessed event name. Use no proxy metric unless the user approves it. Label an approved proxy.
- Report **Could not measure**. List the missing events with this table: event name, properties, trigger, owner.
- The next action is a pointer: instrument first. `real-plan` Backend scope drafts the events. This skill writes no code.

## Safety

- The skill is read-only. The key comes from the tool connection or from an environment variable.
- If a query fails, the status is **Could not measure**. Never fill the gap with a guess.
- The analytics tool can change its schema or its tools. Check each field that you read.
- Personal data stays in the source. Query aggregates. Show no person-level row.
