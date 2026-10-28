# Monetization audit mode

Use this mode for a selected audit of an existing revenue model, pricing, packaging, paywall, purchase/subscription journey or revenue measurement.
- This is a separately selectable mode within Real Audit. It is not a separate automatic audit on every screen.
- Honor the scope choice of the entrypoint.
- A full-product audit includes a baseline applicability check. Detailed market research, analytics work and experiments need a selected scope.
- If there is no revenue model, record not applicable, or record an explicit product decision to investigate one. Do not invent a paywall requirement.

## Evidence and authority

Read `reporting.md`. An audit writes a local report. It does not write prices, offers, billing configuration or experiments.
- Never start a real payment, refund, cancellation, campaign or customer message without applicable explicit authorization.
- Reproduce mutations with disposable accounts and sandbox billing. If these are not available, report the behavior as unverified.

Find the existing product and marketing context before you ask questions.
- Record the current model, audience, market/currency, packages, prices, renewal periods, trial eligibility and promised value.
- Distinguish source/configuration, sandbox behavior and live store/billing evidence.
- Verify the current platform rules and market prices with current primary sources. Do not treat old books or generic skill benchmarks as live pricing evidence.

## Audit areas

1. **Value and packaging:** audit these items:
   - the valuable outcome that users pay for, and when users experience it
   - the free/paid boundaries
   - the needs of segments
   - understandable package differences
   - the unit charged (seat, use, output, subscription)

   Separate observed confusion from willingness-to-pay hypotheses.
2. **Price structure:** total charge, period, currency, taxes where applicable, renewal and trial disclosures, accurate savings claims, discounts and unit economics.
   - Compare plausible models only when relevant.
   - Do not assume that annual plans, .99 endings, fixed discount percentages or three tiers improve results everywhere.
3. **Paywall experience:** timing relative to the value moment, benefit clarity, relevant choices, accessible pricing and controls, honest eligibility and offer terms. Do not recommend fabricated scarcity, concealed renewal charges or obstructive cancellation.
4. **Purchase and entitlement lifecycle:** success, user cancellation, pending/failed payment, duplicate taps, offline recovery, restore, cross-device state, upgrade/downgrade, expiration, billing retry, refund/revocation and cancellation messaging where supported. Share Quality/Security evidence. Merge duplicate root causes.
5. **Measurement and economics:** audit these items:
   - eligibility and exposure events
   - purchase and renewal outcomes
   - cohort trial-to-paid conversion
   - retained paid users, churn and refunds
   - revenue and contribution, after applicable platform fees and service costs
   - For every metric that you use, define the numerator, denominator, cohort/window, currency, gross/net basis, exclusions and data source.
   - Do not divide unmatched cohorts.
   - CAC, LTV and payback need appropriate cost and retention evidence. Mark unavailable estimates unverified.
6. **Measurement gaps:** for each unresolved commercial question, state the hypothesis, the instrumentation that is missing and the decision that it blocks.
   - Do not design the pricing change, the packaging or the experiment. That is the call of the reader.
   - Without baseline and sample-size inputs, do not invent uplift, sample counts, run duration or revenue forecasts.
   - Format user follow-up work as validation tasks in `reporting.md`.
   - Small usability rounds can show price or offer comprehension problems. They cannot establish willingness to pay, an optimal price or conversion uplift.

## Deliverable

Use the shared High/Medium/Low report and actual screenshots for inspected interface states. Separate verified defects from commercial hypotheses and measurement gaps.
- Include the current model and offer truth, the inspected purchase journeys, the metric definitions and the evidence limits.
- Then include the prioritized fixes and the proposed experiments.
- A broken purchase flow can be a verified high-priority defect.
- A claim that a different price will earn more needs a test. Do not present it as proven.

## Pricing evaluation

Use the following questions as a conceptual lens. They are not a live benchmark and not a universal pricing recipe.

- **Value created and communicated:** identify the outcome that users value, and whether they understand it before they pay. Evidence of delivered value and perceived value are separate. A feature list does not establish willingness to pay.
- **Profit as well as conversion:** for a commercial objective, examine revenue and the associated cost/margin tradeoff. Higher conversion or sales alone does not establish better economics. Do not impose profit as the goal of a noncommercial product.
- **Price architecture:** describe the structure that is actually in use. Show where it fits the usage/value pattern of the product badly. Cite the observed effect on light or heavy users and on service costs. Report the mismatch. To select a different structure is the decision of the reader, not of the audit.

Historical company figures, price points and market conditions are not current evidence. Do not import assumptions such as near-zero marginal digital costs into AI or other usage-cost products. A pricing hypothesis still needs product-specific evidence and an appropriately designed test.
