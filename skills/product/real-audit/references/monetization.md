# Monetization audit mode

Use for a selected audit of an existing revenue model, pricing, packaging, paywall, purchase/subscription journey or revenue measurement. This is a separately selectable mode within Real Audit, not a separate automatic audit on every screen. Honor the entrypoint scope choice. A full-product audit includes a baseline applicability check; detailed market research, analytics work and experiments require selected scope. If there is no revenue model, record not applicable or an explicit product decision to investigate one; do not invent a paywall requirement.

## Evidence and authority

Read `reporting.md`. Audit writes a local report, not prices, offers, billing configuration or experiments. Never initiate a real payment, refund, cancellation, campaign or customer message without applicable explicit authorization. Reproduce mutations with disposable accounts and sandbox billing. If unavailable, report unverified behavior.

Find existing product/marketing context before asking questions. Record current model, audience, market/currency, packages, prices, renewal periods, trial eligibility and promised value. Distinguish source/configuration, sandbox behavior and live store/billing evidence. Verify current platform rules and market prices using current primary sources; do not treat old books or generic skill benchmarks as live pricing evidence.

## Audit areas

1. **Value and packaging:** what valuable outcome is paid for, when users experience it, free/paid boundaries, segment needs, understandable package differences and the unit charged (seat, use, output, subscription). Separate observed confusion from willingness-to-pay hypotheses.
2. **Price structure:** total charge, period, currency, taxes where applicable, renewal and trial disclosures, accurate savings claims, discounts and unit economics. Compare plausible models only when relevant. Do not assume annual plans, .99 endings, fixed discount percentages or three tiers universally improve results.
3. **Paywall experience:** timing relative to the value moment, benefit clarity, relevant choices, accessible pricing and controls, honest eligibility and offer terms. Do not recommend fabricated scarcity, concealed renewal charges or obstructive cancellation.
4. **Purchase and entitlement lifecycle:** success, user cancellation, pending/failed payment, duplicate taps, offline recovery, restore, cross-device state, upgrade/downgrade, expiration, billing retry, refund/revocation and cancellation messaging where supported. Share Quality/Security evidence and merge duplicate root causes.
5. **Measurement and economics:** eligibility and exposure events, purchase and renewal outcomes, cohort trial-to-paid conversion, retained paid users, churn, refunds, revenue and contribution after applicable platform fees and service costs. Define numerator, denominator, cohort/window, currency, gross/net basis, exclusions and data source for every metric used. Avoid dividing unmatched cohorts. CAC, LTV and payback require appropriate cost and retention evidence; mark unavailable estimates unverified.
6. **Experiment proposal:** for each opportunity specify the hypothesis, segment, change, primary outcome, retention/refund guardrails, required instrumentation and decision rule. Without baseline and sample-size inputs, do not invent uplift, sample counts, run duration or revenue forecasts. Propose experiments; do not launch them. Format user follow-up work as validation tasks in `reporting.md`; small usability rounds can reveal price/offer comprehension problems but cannot establish willingness to pay, an optimal price or conversion uplift.

## Deliverable

Use the shared High/Medium/Low report and actual screenshots for inspected interface states. Separate verified defects from commercial hypotheses and measurement gaps. Include current model/offer truth, inspected purchase journeys, metric definitions and evidence limits, then prioritized fixes and proposed experiments. A broken purchase flow can be a verified high-priority defect; a claim that a different price will earn more requires testing and cannot be presented as proven.

## Pricing evaluation

Use the following questions as a conceptual lens, not a live benchmark or a universal pricing recipe.

- **Value created and communicated:** identify the outcome users value and whether they understand it before paying. Evidence of delivered value and perceived value are separate; a feature list does not establish willingness to pay.
- **Profit as well as conversion:** for a commercial objective, examine revenue and the associated cost/margin tradeoff. Higher conversion or sales alone does not establish better economics. Do not impose profit as the goal of a noncommercial product.
- **Price architecture:** consider fixed plus usage-based charges, packages or freemium when the product's usage/value pattern warrants it. Compare effects on light/heavy users and service costs. Two-part pricing is an option, not a mandatory recommendation.

Historical company figures, price points and market conditions are not current evidence. Do not import assumptions such as near-zero marginal digital costs into AI or other usage-cost products. A pricing hypothesis still needs product-specific evidence and an appropriately designed test.
