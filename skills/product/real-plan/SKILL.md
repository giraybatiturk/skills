---
name: real-plan
description: "Plan new features and product changes before implementation: user stories, requirements, architecture and acceptance criteria. Use for planla or shaping a chosen but unsettled idea; to generate options or judge whether an idea would work, use real-brainstorm. Reuse existing approval. Do not plan again for approved edits. (v0.8.0)"
license: MIT
metadata:
  author: Giray Batıtürk
  version: 0.8.0
  source: https://github.com/giraybatiturk/skills
---

# Real plan

## Work proportional to the decision

First find the smallest useful next outcome. Reuse existing behavior, components and platform capabilities.
- Do not add speculative abstractions, dependencies or future scope.
- Simplicity never removes required security, accessibility, recovery or verification.

If a material prerequisite is not resolved, ask only 1–3 independent questions that unlock the next decision. Examples of prerequisites: platform, delivery channel, intended outcome.
- Give concise choices and a recommendation.
- Stop the dependent plan there.
- Do not produce a schema, API design, exhaustive acceptance matrix or five-heading draft before the user answers.
- Continue useful independent evidence gathering.
- Existing approval and known facts bypass this intake.

When the prerequisites are settled, give the five headings at the depth that the selected scope needs.
- In chat, give the decision first, then up to five important items.
- Put necessary detail in one linked local report when permitted.
- If you can use chat only, use compact sections. Do not omit required evidence.
- End with one next action only if work remains. Do not give the user work that the agent can do.
- Report observed duration or grounded estimates only. Never invent timing.

Start with the story of the user and the current evidence. Reuse facts that you already established in the conversation. Do not make the user repeat them.

Keep three things separate: observed implementation, unknown implementation and proposed scope.
- A missing feature does not prove that its supporting components are absent. A single user does not prove that authentication is absent.
- Do not attribute these deductions to a source that does not state them.
- A proposed mechanism is a hypothesis until you verify it. A flag or the order of operations alone does not prove atomicity, exactly-once delivery or crash recovery.
- Include the failure and concurrency tests that establish such guarantees.
- Before you send, inspect every claim that a mechanism prevents duplicates, ensures delivery or guarantees recovery.
- An identifier, flag, queue or ordering is a proposed mechanism. It is not proof.
- Without an inspected contract or executed tests, keep the guarantee unverified. Say so in that same sentence.

When the platform or delivery mechanism is not resolved:
- Keep the dependent API, accessibility, timing and integration requirements conditional.
- Do not prescribe web-only semantics for an unknown or native platform.
- Do not state that network or secrets are absent without evidence.
- A numeric acceptance target needs a stated requirement of the user or project. Or label it clearly as a proposal to validate. Precision alone is not evidence.
- Apply the orchestration triggers to the decisions that you make now. Record the deferred provider-dependent decisions. Do not declare them settled.

1. If the idea or decision is unsettled, read `references/discovery.md` and resolve only the open branches.
2. For a product or code change, read `references/feature-gate.md` and inspect the repository and running system read-only.
3. Show these five headings before implementation: **User story**, **Analysis**, **Backend scope**, **Frontend scope**, **Connection**.
4. Include measurable acceptance criteria. Label anything unavailable as **Could not measure**, with who or what can verify it.
5. Wait for approval of the five headings before you edit implementation files. Existing session approval stays valid when the scope has not changed.

After approval, when writing is permitted, save the five headings and acceptance criteria to `docs/plans/YYYY-MM-DD-<slug>.md` in the current project, unless the user names another place. Link it in chat. If writing is not permitted, stay chat-only.

Optional handoff: the approved plan can have acceptance criteria for a web app flow. Then offer to save them as a flows file next to the plan: `docs/plans/YYYY-MM-DD-<slug>-flows.txt`.
- Write one flow on each line in plain text. Do not use bullets or numbering.
- Do this only if `real-test` is in the skill catalog of your tool. Then add one line at the end: "Next, optional: after implementation, `/real-test <url> --flows <file>`."
- If `real-test` is not installed, skip this silently. Never start it.

This workflow needs real-audit from the same bundle.
- Resolve its installed location from the skill catalog of your tool. Or use the adjacent `../real-audit` folder if it is there.
- If it is not available, report the missing dependency. Ask the user to install the full Real bundle. Do not invent its rules. Do not continue dependent work.

Read the resolved real-audit `references/product-context.md` for shared context persistence.
- Reuse the canonical `PRODUCT.md` of the project and the prior answers.
- During discovery, before the handoff to design or implementation, save verified durable product facts there.
- Obey explicit read-only limits.
- Context documentation is not implementation approval.
- Keep candidate stories and proposed changes in planning documents. Link approved story records. Do not copy them into PRODUCT.md.
- Do not create or change DESIGN.md during product intake. A separate applicable design-policy authorization is required.

For UI work, read the resolved real-audit `references/design-rules.md`. The `DESIGN.md` of the project takes precedence.

Keep a small, reversible change with a single agent. Read the resolved real-audit `references/orchestration.md` to find the triggers. Follow them.
