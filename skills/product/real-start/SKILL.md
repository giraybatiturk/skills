---
name: real-start
description: "Route unclear product work: where to start, nereden başlayalım, or mixed planning, audit and research requests. Select the smallest Real workflow; skip routing for simple edits or already-approved implementation."
---

# Real start

Choose and invoke the smallest workflow that can finish the request. Do not make the user type another command.

Carry evidence limits through the recommendation as well as the findings. If analytics or feedback are not supplied, first locate or request existing evidence; do not assume they need to be created from scratch. Proposed next checks are not proven defects or mandatory new features.

Keep the router's handoff short. Ask at most 1–3 independent questions that change the next step; defer dependent choices. Lead with the selected route and end with one next action if needed. Reuse a sufficient existing solution and skip speculative stages. If the selected workflow cannot proceed because the product evidence is unavailable, report the selected route, the exact missing evidence and the next useful read-only step. Do not simulate a full downstream audit with speculative features, risk rankings or repeated summaries of missing evidence.

Use the client's skill invocation tool or read the selected skill at its catalog-provided path. Do not claim it ran before its instructions load. If unavailable, state the missing capability; do not guess paths. An already-approved implementation goes directly to execution and appropriate verification, without restarting planning.

## Shared project context

Read the project's existing `PRODUCT.md` before routing and carry its resolved path plus known answers forward. Use the catalog-resolved Real Audit `references/product-context.md` (or verified adjacent `../real-audit/references/product-context.md`) as the shared persistence contract. Let the selected Plan/Audit workflow fill and save confirmed missing facts; the router must not create a second record or interview. Preserve DESIGN.md as read-only unless design-policy work was explicitly requested. Missing PRODUCT.md alone does not block a focused task or already-approved implementation.

## Product maturity before routing

When receiving an audit request or handoff, carry forward any established product context and scope. Distinguish three cases:

- **Confirmed idea only / product not formed:** route to `real-plan` discovery to clarify purpose, users/buyers, intended outcome, candidate user stories and the smallest testable slice. Do not invoke audit merely because the original request used the word audit.
- **Design or prototype:** if the user wants review of that artifact, route to a bounded `real-audit` Design/Module review of demonstrable behavior. Do not claim live-product, billing or release verification. If the request is instead to define/build the product, use Plan.
- **Existing product:** route to the selected audit scope and modes. Missing access, documents or screenshots does not prove the product does not exist; request the exact missing evidence or continue independent checks.

Do not loop between Start and Audit. An Audit handoff that confirms idea-only goes to Plan, not back to Audit. Load the destination instructions and continue without requiring the user to type another command. If the user explicitly requests critique of an idea only, honor that bounded request and label it conceptual rather than runtime audit.

## Routing

- **Plan**: a new feature, change, decision, requirement, or idea that is not approved yet. Invoke `real-plan`.
- **Audit**: improve an existing product, inspect what is missing, review a built module or screen, measure performance, or decide the next release. Invoke `real-audit` with the appropriate mode.
- **Research**: the decision depends on current external facts, official documentation, competitor behavior, pricing, policy, or provider limits. Invoke `real-research`.

If the request spans workflows, use this order: research unresolved external facts, plan the change, implement only after approval, then audit the result. Skip stages whose evidence is already settled.

Legacy mapping: `real-grill` and `real-feature-gate` are now `real-plan`; `real-product-audit`, `real-module-audit`, `real-design-audit`, and `real-perf-audit` are modes of `real-audit`.
