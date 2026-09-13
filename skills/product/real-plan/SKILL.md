---
name: real-plan
description: "Plan new features and product changes before implementation: user stories, requirements, architecture and acceptance criteria. Use for planla or an unsettled idea; reuse existing approval and skip renewed planning for approved edits."
---

# Real plan

## Work proportional to the decision

First identify the smallest useful next outcome. Reuse existing behavior, components and platform capabilities; do not add speculative abstractions, dependencies or future scope. Simplicity never removes required security, accessibility, recovery or verification.

If a material prerequisite such as platform, delivery channel or intended outcome is unresolved, ask only 1–3 independent questions that unlock the next decision, with concise choices and a recommendation. Stop the dependent plan there. Do not produce a schema, API design, exhaustive acceptance matrix or five-heading draft before those answers. Continue useful independent evidence gathering. Existing approval and known facts bypass this intake.

Once prerequisites are settled, give the five headings at the depth the selected scope requires. Lead chat with the decision and up to five important items; put necessary detail in one linked local report when permitted. If chat-only, use compact sections without omitting required evidence. End with one next action only if work remains; do not assign the user work the agent can do. Report observed duration or grounded estimates only, never invented timing.

Start with the user's story and current evidence. Reuse facts already established in the conversation; do not make the user repeat them.

Keep observed implementation, unknown implementation and proposed scope separate. A missing feature does not prove its supporting components are absent; single-user does not prove authentication is absent. Do not attribute these deductions to a source that does not state them. Proposed mechanisms are hypotheses until verified: a flag or ordering of operations alone does not prove atomicity, exactly-once delivery or crash recovery. Include the failure/concurrency checks required to establish such guarantees. Before sending, inspect every claim that a mechanism prevents duplicates, ensures delivery or guarantees recovery. An identifier, flag, queue or ordering is a proposed mechanism, not proof. Without inspected contract or executed checks, explicitly keep the guarantee unverified in that very sentence.

When the platform or delivery mechanism is unresolved, keep dependent API, accessibility, timing and integration requirements conditional. Do not prescribe web-only semantics for an unknown/native platform or state that network/secrets are absent without evidence. Numeric acceptance targets require a stated user/project requirement or an explicitly labeled proposal to validate; precision alone is not evidence. Apply orchestration triggers to decisions being made now, and record deferred provider-dependent decisions rather than declaring them settled.

1. If the idea or decision is unsettled, read `references/discovery.md` and resolve only the open branches.
2. For a product or code change, read `references/feature-gate.md` and inspect the repository and running system read-only.
3. Show these five headings before implementation: **User story**, **Analysis**, **Backend scope**, **Frontend scope**, **Connection**.
4. Include measurable acceptance criteria and label anything unavailable as **Could not measure**, with who or what can verify it.
5. Wait for approval of the five headings before editing implementation files. Existing session approval remains valid when the scope has not changed.

This workflow requires real-audit from the same bundle. Resolve its installed location from the client's skill catalog, or use the adjacent `../real-audit` directory if present. If unavailable, report the missing dependency and request installation of the full four-skill bundle; do not invent its rules or continue dependent work.

Read the resolved real-audit `references/product-context.md` for shared context persistence. Reuse the canonical project `PRODUCT.md` and prior answers; save confirmed durable product facts there during discovery, before handoff to design/implementation. Respect explicit read-only limits. Context documentation is not implementation approval. Keep candidate stories and proposed changes in planning documents, and link approved story records instead of copying them into PRODUCT.md. Do not create or modify DESIGN.md during product intake; a separate applicable design-policy authorization is required.

For UI work, read the resolved real-audit `references/design-rules.md`; the project's own `DESIGN.md` takes precedence.

Keep a small, reversible change single-agent. Read the resolved real-audit `references/orchestration.md` to determine triggers and follow them.
