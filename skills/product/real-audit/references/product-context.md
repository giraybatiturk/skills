# Product context and story contract

Use a lightweight product-manager intake before a broad product/critical-journey audit. A focused screen, function, security or bug audit only needs context that can change its verdict; do not force a full product interview. Context informs audit criteria, not permission to change the product.

## Reuse evidence first

Read applicable project instructions, the resolved `PRODUCT.md`, product/marketing context, README, approved stories, prior reports and the conversation within the authorized project. Summarize what is known with sources. Do not ask the user to repeat established answers. Distinguish **Confirmed**, **Inferred** and **Unknown**; implemented behavior alone is not proof of user need or intended behavior.

Establish these fields only to the depth needed for the selected scope:

- **Purpose and stage:** what outcome the product promises and whether it is an idea, prototype, live product or internal tool.
- **Users and buyers:** the primary user, usage context, problem/current alternative, and payer/decision-maker if different. Do not invent personas or demand.
- **Success:** the user's valuable outcome and the product owner's current objective: revenue/profit, adoption/retention, internal efficiency, public benefit or another stated goal. Monetization is not every product's purpose.
- **Journey:** the main job, entry point, value moment, completion/recovery and return trigger, with relevant roles and platforms.
- **Constraints and evidence:** release/scope limits, supported markets/platforms, data access, current acceptance criteria and meaningful success evidence. Do not invent numerical targets.

## Ask only what changes the audit

If necessary fields are missing or contradictory, ask at most three short, tailored questions in one batch. Offer three concrete choices where meaningful, including "not decided" for unsettled product decisions; allow free text. Adapt choices to the evidence rather than asking a generic checklist. Combine with the scope chooser when possible. Show inferred answers for correction rather than requesting fresh descriptions of everything.

If the target user, business purpose or promised outcome is undecided, mark dependent product/monetization judgments **Unverified**. Continue independent interface, correctness or security checks. If the product is confirmed idea-only, use the entrypoint `real-start` handoff. For an existing product with unsettled strategy, offer a bounded `real-plan` discovery step; do not automatically create a strategy, pricing model or full roadmap. Do not turn uncertainty about revenue into a recommendation to add subscriptions.

## User story map as the audit contract

Use a lightweight activity/task map for the selected journey. Reuse approved stories first. If absent, derive a small set of **candidate stories** from available evidence, explicitly identifying their source and inferred status. Confirm only those whose interpretation materially changes a verdict; a candidate is not an approved requirement.

Write outcome-based stories: "As [role], I want [action/outcome], so that [benefit]." Avoid merely renaming UI controls as stories. Include preconditions, applicable acceptance criteria, failure/recovery and permissions. Do not create new feature requirements from the absence of an optional feature.

Review the stories themselves: is the role/outcome clear, is the benefit supported by user/product evidence, are acceptance criteria observable, are contradictions and necessary failure paths addressed? Keep story/requirement gaps separate from verified implementation defects.

Trace each story:

`Story ID and authority -> journey step -> screens/states -> acceptance criterion -> source/runtime/test evidence -> Verified / Failed / Unverified / Not applicable -> finding IDs`

A passing screen does not prove the complete story succeeded. Source-only behavior cannot satisfy an end-to-end criterion. For full scope, preserve the complete screen/state inventory even if some screens cannot yet be mapped to a confirmed story.

## Route from context, then report and plan

- UX/Design: clarity, navigation, interaction and state presentation.
- Module/Quality: story acceptance, contracts, recovery and actual outcomes.
- Security/Privacy: relevant roles, sensitive data and trust boundaries.
- Monetization: a selected revenue question or baseline check of an existing/planned revenue model. Revenue goals alone do not authorize a detailed monetization expansion.
- Performance: relevant observed runtime concerns using platform-appropriate evidence.

Show the context card, selected modes and scope once before detailed work; do not add another approval gate when the request is already clear. Report using `reporting.md`, with story traceability and context gaps. Audit may recommend an order for fixes. When planning is requested, hand off selected finding/story IDs, evidence, impact, dependencies and acceptance criteria to `real-plan`. Do not auto-implement or restart discovery already completed; preserve existing applicable approvals.

## Persist one shared product record

`PRODUCT.md` is the durable product record shared by Real Start, Real Plan and Real Audit. Reuse the project's existing canonical record and path instead of creating a competing context file. Resolve the actual product/app root from the request and project boundaries, not blindly from cwd. In a monorepo, preserve root-inherited facts and identify app-specific scope; clarify ownership only if ambiguous. Never put a customer's product record into the global skill folder or an unrelated workspace.

For a broad intake or product-definition workflow, save confirmed durable facts to the resolved `PRODUCT.md`; if no record exists, use `<product-root>/PRODUCT.md`. The user's answers or already explicit session facts provide confirmation; do not require a repeated approval of the same facts. If only repository inferences exist, present a concise draft and obtain confirmation before promoting them to product truth. A focused audit must not force creation of PRODUCT.md. If the user requests strictly read-only work or report-only output, keep a proposed record in that permitted output rather than writing PRODUCT.md.

Use this sequence:

1. Read the existing record and relevant source documents. Preserve useful headings, existing manual content and references.
2. Resolve material gaps in the same bounded intake, not a second interview. Mark undecided matters explicitly; do not fill them with generic assumptions.
3. Apply only confirmed additions/corrections. When a new answer contradicts the existing record, surface the conflict and update only after the user makes the intended change clear. Record the source and verification date for changed durable facts; do not rewrite unrelated sections or stale facts without checking them.
4. Reopen the saved file and verify its path and contents. Pass that path, remaining open decisions and story references to the next workflow. Report whether context was saved, reused unchanged, or remains a draft.

Use consistent section names in new records. Record `## Platform` only when established, using the actual product platform; leave unknown details explicitly undecided rather than defaulting to web. Useful sections are `## Users`, `## Product Purpose`, `## Positioning`, `## Operating Context`, `## Capabilities and Constraints`, `## Brand Commitments`, `## Evidence on Hand`, `## Product Principles`, and `## Accessibility & Inclusion`. Omit irrelevant sections. Add `## Business Model` for confirmed commercial/noncommercial intent, buyer and revenue model, `## Open Decisions`, and `## Sources and Verification` as needed. Record a stack only when established or explicitly delegated.

Real maintains this record independently. Do not add another tool's schema markers, configuration defaults, invocation requirements or product-record copies. Preserve existing metadata owned by other tools without claiming to manage it. Keep workflow settings separate from product truth.

## Keep product, stories, design and audit evidence separate

- **PRODUCT.md:** stable purpose, users/buyers, platform, business intent, constraints and pointers to existing story/plan documents. Keep dated metrics in referenced reports rather than presenting them as timeless product facts. No secrets or unnecessary personal data.
- **Stories and plans:** reuse the project's established location. Candidate stories stay in the audit/report or planning draft; only approved stories enter the canonical requirements. Link from PRODUCT.md rather than duplicating the backlog.
- **DESIGN.md:** read as the canonical design authority. Product intake and an ordinary audit never create, rewrite, weaken or synchronize it automatically. Missing DESIGN.md does not imply no existing visual identity; inspect the incumbent interface and report baseline assumptions. A violated design rule is not permission to rewrite that rule.
- **Audit report and captures:** use the project's existing audit/report location, with dated evidence and links to the applicable product/story/design record. Keep repeated findings out of PRODUCT.md.

An explicit request to document the existing design system should derive the record from the implemented interface and verified assets. Authorized redesign/design-system work may update DESIGN.md and related design metadata within that scope. A request to fix an interface does not automatically authorize replacing design policy; first fix against the existing contract and propose any necessary policy change separately. Prior explicit authorization to update design policy remains valid. Never modify DESIGN.md merely to make a finding pass.
