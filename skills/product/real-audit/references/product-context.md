# Product context and story contract

Use a lightweight product-manager intake before a broad product or critical-journey audit.
- A focused audit of a screen, function, security or bug needs only the context that can change its verdict. Do not force a full product interview.
- Context informs the audit criteria. It is not permission to change the product.

## Reuse evidence first

Read these sources within the authorized project:
- the applicable project instructions
- the resolved `PRODUCT.md`
- product and marketing context, README, approved stories and prior reports
- the conversation

Then:
- Summarize what is known, with sources.
- Do not ask the user to repeat established answers.
- Distinguish **Confirmed**, **Inferred** and **Unknown**. Implemented behavior alone is not proof of user need or intended behavior.

Establish these fields only to the depth that the selected scope needs:

- **Purpose and stage:** what outcome the product promises, and whether it is an idea, prototype, live product or internal tool.
- **Users and buyers:** the primary user, usage context, problem/current alternative, and payer/decision-maker if different. Do not invent personas or demand.
- **Success:** the valuable outcome for the user, and the current objective of the product owner: revenue/profit, adoption/retention, internal efficiency, public benefit or another stated goal. Monetization is not the purpose of every product.
- **Journey:** the main job, entry point, value moment, completion/recovery and return trigger, with relevant roles and platforms.
- **Artefact type:** what you actually audit: web app or site, native mobile app, hybrid, desktop application, visual deliverable, or a service with no interface.
  - This selects the applicable rule set and the evidence standard.
  - Record it once. Reuse it. Do not ask again in each audit.
  - A product can hold several types. Name each type in scope.
- **Constraints and evidence:** release/scope limits, supported markets/platforms, data access, current acceptance criteria and meaningful success evidence. Do not invent numerical targets.

## Ask only what changes the audit

If necessary fields are missing or contradictory, ask at most three short, tailored questions in one batch.
- Offer three concrete choices where meaningful. Include "not decided" for unsettled product decisions. Allow free text.
- Adapt the choices to the evidence. Do not ask a generic checklist.
- When possible, combine them with the scope chooser.
- Show inferred answers for correction. Do not ask for fresh descriptions of everything.

If the target user, business purpose or promised outcome is undecided, mark the dependent product and monetization judgments **Unverified**. Continue independent interface, correctness or security tests.
- If the product is confirmed idea-only, use the `real-start` handoff of the entrypoint.
- For an existing product with unsettled strategy, offer a bounded `real-plan` discovery step. Do not create a strategy, pricing model or full roadmap automatically.
- Do not turn uncertainty about revenue into a recommendation to add subscriptions.

## User story map as the audit contract

Use a lightweight activity/task map for the selected journey. Reuse approved stories first.
- If there are none, derive a small set of **candidate stories** from the available evidence. Identify their source and inferred status explicitly.
- Ask the user to confirm only the stories whose interpretation changes a verdict materially. A candidate is not an approved requirement.

Write outcome-based stories: "As [role], I want [action/outcome], so that [benefit]."
- Do not only rename UI controls as stories.
- Include preconditions, applicable acceptance criteria, failure/recovery and permissions.
- Do not create new feature requirements from the absence of an optional feature.

Review the stories themselves:
- Is the role/outcome clear?
- Does user or product evidence support the benefit?
- Are the acceptance criteria observable?
- Do the stories address contradictions and necessary failure paths?

Keep story and requirement gaps separate from verified implementation defects.

Trace each story:

`Story ID and authority -> journey step -> screens/states -> acceptance criterion -> source/runtime/test evidence -> Verified / Failed / Unverified / Not applicable -> finding IDs`

- A passing screen does not prove that the complete story succeeded.
- Source-only behavior cannot satisfy an end-to-end criterion.
- For full scope, keep the complete screen and state inventory. Do this also when you cannot yet map some screens to a confirmed story.

## Route from context, then report and plan

- UX/Design: clarity, navigation, interaction and state presentation.
- Module/Quality: story acceptance, contracts, recovery and actual outcomes.
- Security/Privacy: relevant roles, sensitive data and trust boundaries.
- Monetization: a selected revenue question, or a baseline check of an existing or planned revenue model. Revenue goals alone do not authorize a detailed monetization expansion.
- Performance: relevant observed runtime concerns, with platform-appropriate evidence.

Show the context card, the selected modes and the scope one time before detailed work. When the request is already clear, do not add another approval gate.

Report with `reporting.md`, with story traceability and context gaps.
- An audit can recommend an order for fixes.
- When the user asks for planning, hand off these items to `real-plan`:
  - the selected finding and story IDs
  - the evidence and the impact
  - the dependencies
  - the acceptance criteria
- Do not implement automatically. Do not restart discovery that is already complete. Keep existing applicable approvals.

## Persist one shared product record

`PRODUCT.md` is the durable product record that Real Start, Real Plan and Real Audit share.
- Reuse the existing canonical record and path of the project. Do not create a competing context file.
- Resolve the actual product or app root from the request and the project boundaries. Do not use cwd blindly.
- In a monorepo, keep the facts that the root passes down. Identify the app-specific scope. Clarify ownership only if it is ambiguous.
- Never put the product record of a customer in the global skill folder or in an unrelated workspace.

For a broad intake or product-definition workflow, save the confirmed durable facts to the resolved `PRODUCT.md`. If no record exists, use `<product-root>/PRODUCT.md`.
- The answers of the user, or session facts that are already explicit, give the confirmation. Do not ask again for approval of the same facts.
- If only repo inferences exist, present a concise draft. Get confirmation before you promote them to product truth.
- A focused audit must not force the creation of PRODUCT.md.
- If the user requests strictly read-only work or report-only output, keep a proposed record in that permitted output. Do not write PRODUCT.md.

Use this sequence:

1. Read the existing record and the relevant source documents. Keep the useful headings, the existing manual content and the references.
2. Resolve material gaps in the same bounded intake, not in a second interview. Mark undecided matters explicitly. Do not fill them with generic assumptions.
3. Apply only confirmed additions and corrections.
   - When a new answer contradicts the existing record, show the conflict. Update only after the user makes the intended change clear.
   - Record the source and the verification date for changed durable facts.
   - Do not rewrite unrelated sections or stale facts without verifying them.
4. Reopen the saved file. Verify its path and contents. Pass that path, the remaining open decisions and the story references to the next workflow. Report if the context was saved, reused unchanged, or remains a draft.

Use consistent section names in new records.
- Record `## Platform` only when it is established. Use the actual product platform. Leave unknown details explicitly undecided. Do not default to web.
- Useful sections are `## Users`, `## Product Purpose`, `## Positioning`, `## Operating Context`, `## Capabilities and Constraints`, `## Brand Commitments`, `## Evidence on Hand`, `## Product Principles`, and `## Accessibility & Inclusion`. Omit irrelevant sections.
- Add `## Business Model` for confirmed commercial or noncommercial intent, buyer and revenue model. Add `## Open Decisions` and `## Sources and Verification` as needed.
- Record a stack only when it is established or explicitly delegated.

Real maintains this record independently.
- Do not add the schema markers, configuration defaults, invocation requirements or product-record copies of another tool.
- Keep the existing metadata that other tools own. Do not claim to manage it.
- Keep workflow settings separate from product truth.

## Keep product, stories, design and audit evidence separate

- **PRODUCT.md:** stable purpose, users/buyers, platform, business intent, constraints and pointers to existing story and plan documents. Keep dated metrics in referenced reports. Do not present them as timeless product facts. No secrets or unnecessary personal data.
- **Stories and plans:** reuse the established location of the project. Candidate stories stay in the audit report or the planning draft. Only approved stories enter the canonical requirements. Link from PRODUCT.md. Do not duplicate the backlog.
- **DESIGN.md:** read it as the canonical design authority.
  - Product intake and an ordinary audit never create, rewrite, weaken or synchronize it automatically.
  - A missing DESIGN.md does not imply that there is no existing visual identity. Inspect the incumbent interface and report the baseline assumptions.
  - A violated design rule is not permission to rewrite that rule.
- **Audit report and captures:** use the existing audit or report location of the project, with dated evidence and links to the applicable product, story and design record. Keep repeated findings out of PRODUCT.md.

An explicit request to document the existing design system: derive the record from the implemented interface and the verified assets.
- Authorized redesign or design-system work can update DESIGN.md and related design metadata within that scope.
- A request to fix an interface does not authorize replacing design policy automatically. First fix against the existing contract. Propose any necessary policy change separately.
- Prior explicit authorization to update design policy stays valid.
- Never change DESIGN.md only to make a finding pass.
