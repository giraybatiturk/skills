---
name: real-start
description: "Route unclear product work: where to start, nereden başlayalım, or mixed planning, audit, check, test and research requests. Select the smallest Real workflow. Do not route simple edits or approved implementation. (v0.12.0)"
license: MIT
metadata:
  author: Giray Batıtürk
  version: 0.12.0
  source: https://github.com/giraybatiturk/skills
---

# Real start

Choose and start the smallest workflow that can finish the request. Do not make the user type another command.

- Carry the evidence limits into the recommendation and into the findings.
- If analytics or feedback are missing, first find or request the existing evidence. Do not assume that someone must create them from nothing.
- A proposed next test is not a proven defect. It is not a mandatory new feature.

Keep the handoff of the router short.
- Ask at most 1–3 independent questions that change the next step. Defer dependent choices.
- Start with the selected route. If needed, end with one next action.
- Reuse a sufficient existing solution. Skip speculative stages.
- Sometimes the selected workflow cannot continue, because the product evidence is not available. Then report three things:
  - the selected route
  - the exact missing evidence
  - the next useful read-only step
- Do not simulate a full downstream audit. Do not add speculative features, risk rankings or repeated summaries of missing evidence.

Use the skill invocation tool that you have, or read the selected skill at its catalog path.
- Do not claim that it ran before its instructions load.
- If it is not available, state the missing capability. Do not guess paths.
- Send an approved implementation directly to execution and appropriate verification. Do not restart planning.

## Shared project context

- Read the existing `PRODUCT.md` of the project before you route. Carry its resolved path and the known answers forward.
- Use the Real Audit `references/product-context.md` that the catalog resolves. Or use the verified adjacent `../real-audit/references/product-context.md`. It is the shared persistence contract.
- Let the selected Plan or Audit workflow fill and save the missing facts that the user verified. The router must not create a second record or interview.
- Keep DESIGN.md read-only, unless the user asked for design-policy work.
- A missing PRODUCT.md alone does not block a focused task or an approved implementation.

## Product maturity before routing

When you receive an audit request or handoff, carry forward the established product context and scope. Find which of these three cases applies:

- **Confirmed idea only / product not formed:** route to `real-plan` discovery. Clarify the purpose, users/buyers, intended outcome, candidate user stories and the smallest testable slice. Do not start an audit only because the original request used the word audit.
- **Design or prototype:** if the user wants a review of that artifact, route to a bounded `real-audit` Design/Module review. Review only the behavior that you can show.
  - Do not claim live-product, billing or release verification.
  - If the request is to define or build the product, use Plan.
- **Existing product:** route to the selected audit scope and modes. Missing access, documents or screenshots do not prove that the product does not exist. Request the exact missing evidence, or continue independent tests.

Do not loop between Start and Audit.
- If an Audit handoff shows that the product is an idea only, it goes to Plan. It does not go back to Audit.
- Load the instructions of the destination and continue. Do not make the user type another command.
- If the user asks for a critique of an idea only, do that bounded request. Label it conceptual, not a runtime audit.

## Routing

- **Brainstorm**: no candidate exists yet, or the user wants an idea judged on whether it would work, sell or earn. Start `real-brainstorm`.
- **Plan**: a new feature, change, decision, requirement, or idea that is not approved yet. Start `real-plan`.
- **Audit**: your own product in depth (repo, running app, screens). Use it to improve an existing product, find what is missing, or review a built module or screen. Use it also to measure performance or decide the next release. Start `real-audit` with the appropriate mode.
- **Check**: a quick, rule-based scan of a public URL (no AI, read-only). Use it for a site that someone else owns (customer, prospect, competitor). Use it also for a one-page report or an outreach draft for the site owner. It needs no code or account access. Start `real-check`.
- **Test**: persistent end-to-end tests for the key user flows of your own web app (local, staging or a URL that you own).
  - An AI explores the app. The user approves a plan. The Playwright tests stay in the repo.
  - The tests run at desktop and phone width (Firefox and WebKit are optional). They are healed once.
  - The report adds accessibility findings and a visual comparison with the last run.
  - Reruns need no model.
  - It is not a public-URL scan (Check). It is not an in-depth product review (Audit).
  - Start `real-test`.
- **Research**: the decision depends on current external facts, official documentation, competitor behavior, pricing, policy, or provider limits. Start `real-research`.

If the request spans workflows, use this order:
1. Research unresolved external facts.
2. Brainstorm, when no candidate exists.
3. Plan the change.
4. Implement, only after approval.
5. Audit the result.
6. When the app runs, test its key flows.

Skip each stage whose evidence is already settled.

Legacy mapping: `real-grill` and `real-feature-gate` are now `real-plan`. `real-product-audit`, `real-module-audit`, `real-design-audit`, and `real-perf-audit` are modes of `real-audit`.
