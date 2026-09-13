# Product audit mode

Audit the product that actually exists. Produce an evidence-backed product decision document, not a generic checklist or an invented roadmap.

## Questions to answer

1. What product exists today, for whom, and which outcome does it promise?
2. Which complete user journeys work, fail, or remain unverified?
3. Where do product claims, user stories, implementation, tests, telemetry, pricing, and store messaging disagree?
4. What belongs in Now, Next, Later, and Not doing?
5. What coherent next release should ship, and how will its success be measured?

## Evidence rules

- Inspect the repository, running product, product documents, store material, analytics definitions, support evidence, and delivery configuration that are available.
- Measure before recommending. Label statements as **Fact**, **Inference**, or **Decision** when the distinction matters.
- Write **Could not measure** for unavailable analytics, user evidence, external systems, or live behavior. Name who or what can verify it.
- Never invent baselines, targets, dates, owners, revenue, conversion, retention, or user demand.
- Identify the canonical source for each product claim. Record contradictions instead of silently choosing one.
- This audit writes a report. It does not change product behavior, pricing, roadmap systems, analytics, releases, or live configuration.

## Workflow

### 0. Establish context and story authority

Follow `product-context.md`: reuse confirmed purpose, users/buyers, success criteria and constraints, then ask only unresolved decisions. Review existing stories and label newly derived stories as candidates. Trace approved criteria to runtime evidence; separate story gaps from implementation defects. Do not make new product requirements from today's implementation.

### 1. Inventory product truth

Find evidence for:

- product promise, target users, jobs and constraints
- onboarding, core loop, recovery paths, settings, permissions, subscription and deletion journeys
- shipped features, feature flags, known defects and release state
- user stories, acceptance criteria, tests and localization
- event taxonomy, funnels, retention signals and reporting
- pricing, entitlement behavior, trial, paywall and store presentation
- feedback, support requests, reviews and prior research

Record missing evidence. Do not turn absence into a negative conclusion.

### 2. Audit the product model

State:

- target user and primary problem
- product promise and value moment
- core loop and return trigger
- trust, privacy and failure expectations
- business model and delivery constraints

Compare each statement with observable behavior. Mark it **Aligned**, **Drifted**, **Missing**, or **Could not measure**.

### 3. Trace complete journeys

Map the important journeys from entry to outcome. Include positive and negative user stories plus empty, loading, permission-denied, offline, expired-entitlement, destructive, and recovery states when relevant. Give each story observable acceptance criteria.

For each journey, trace:

`User need -> story -> interface -> domain behavior -> persistence/API -> notification or background behavior -> analytics -> test -> outcome`

Do not count a screen or isolated component as a complete journey.

### 4. Prioritize findings

Use severity first:

- **P0**: safety, privacy, data loss, payment, or release-blocking failure
- **P1**: core outcome is blocked or seriously misleading
- **P2**: recurring friction, weak comprehension, or measurable product drift
- **P3**: polish or low-impact opportunity

Then place work into **Now**, **Next**, **Later**, or **Not doing**. Explain the evidence, user impact, dependency, and tradeoff. Do not fabricate RICE scores when reach, impact, confidence, or effort data is unavailable.

### 5. Build the metric tree

Define one product outcome and its leading indicators. Give exact formulas, required events/properties, exclusion rules, and measurement windows.

Check whether current telemetry can calculate each metric. Separate:

- measurable now
- requires instrumentation
- requires qualitative research
- unsuitable as a success metric

Prefer behavior and retained value over activity totals.

### 6. Audit monetization

Assess whether a revenue model exists and whether pricing, packaging, entitlement, paywall timing, restore, cancellation messaging, and store claims support the product promise. In a full-product audit, record this baseline and any evidence gaps. Use `monetization.md` for a selected detailed monetization audit; do not silently add market research, analytics exports, or experiments to the scope. Treat market prices and platform rules as live facts and verify them before using them.

### 7. Define the next release

Choose the smallest coherent release that improves one user outcome and can be verified. Include:

- release objective
- included and excluded journeys
- acceptance criteria
- instrumentation and QA requirements
- dependencies and risks
- release guardrails
- success and rollback signals

Do not group unrelated backlog items into the release merely because they are nearby.

## Finding format

Use `reporting.md` as the shared presentation contract, retaining the additional product fields below. Map technical severity to High / Medium / Low and retain a separate critical-blocker flag. Use this format for every material finding:

```text
[PA-01] Finding title [P0|P1|P2|P3]
Evidence: repository, runtime, data, or user evidence
Impact: affected user outcome and scope
Today: current observable behavior
Recommend: concrete product decision or investigation
Owner: role or system responsible; "Unassigned" when unknown
Decision: Now | Next | Later | Not doing | Needs evidence
```

## Deliverable

Write the full report to the project's existing product-documentation location. If none exists, use `docs/product-audit-YYYY-MM-DD.md`.

The report must contain:

1. Executive product verdict
2. Evidence inventory and limits
3. Product model alignment
4. Journey and user-story traceability
5. Prioritized findings
6. Metric tree and instrumentation gaps
7. Monetization findings
8. Now / Next / Later / Not doing
9. Proposed next release with acceptance criteria
10. Open decisions and verification owners

Return a concise summary in chat with the report link, top findings, proposed next release, and anything that could not be measured.

## Routing boundaries

- Use `real-plan` when the idea itself is unsettled or a change needs approval.
- Use `real-research` for external facts or market evidence.
- Use `real-audit` Module mode for one implemented module.
- Use `real-audit` Design mode for interface quality.
- Use `real-audit` Performance mode for measured web performance.

Recommend these focused skills when necessary. Do not duplicate or silently launch their workflows inside this audit.
