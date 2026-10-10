# Orchestration rules

Use one agent by default. Split the work when any condition is true:

1. The action is irreversible or externally visible: publishing, deletion, payment, email, messaging, or release.
2. It changes identity, authorization, payment, or personal-data behavior.
3. More than 10 files or more than two repositories are affected.
4. The decision depends on third-party behavior, current external documentation, pricing, policy, or provider limits.
5. The user explicitly asks for orchestration, parallel work, or independent reviews.

For triggered work, use at least two independent perspectives that do not see each other's conclusions, then one adversarial verifier. The verifier must be at least as capable as the strongest producer it checks.

## Execution contract

Before dispatch, give each worker a bounded responsibility, permitted files/resources, necessary context, expected output and observable acceptance criteria. Workers sharing a checkout must preserve each other's changes. Independent assessments must not receive each other's conclusions before synthesis.

Record the actual dispatch handle and terminal result. A planned assignment or a worker's claim is not completed evidence. Verify the deliverable itself against its acceptance criteria; separate passed, failed and unverified results. Resolve conflicting evidence explicitly.

Keep retries bounded. After two failures on the same subtask, reassess the cause, tools or decomposition before another attempt. Do not silently switch providers, expand permissions or spend on a paid fallback. A timeout in observation is not process failure: inspect the original live handle before restarting. Use available native agent tools rather than building a second execution layer unnecessarily.

If delegation is unavailable, disclose the limitation and perform useful authorized serial work; do not pretend independent verification occurred. No model tier name overrides the client's available models or user choice. Apply the same capability requirement to the final verifier, even when the strongest producer is a newer model family.

Choose models by capability, not a pinned version:

| Work | Capability |
|---|---|
| Product architecture and synthesis | strongest available reasoning/product model |
| Adversarial verification | strongest available reasoning model |
| Broad implementation | comprehensive coding model |
| UI/product implementation | balanced coding and visual-reasoning model |
| Mechanical edits and discovery | fastest capable model |

On Codex, this usually maps to Astra for architecture/verification, Sol for broad implementation, Terra for UI/product work, and Luna or Spark for mechanical discovery. On Claude-compatible systems, prefer the highest product/architecture tier available (including Fable when offered), Opus for verification, Sonnet for implementation, and Haiku for discovery. Fall back by capability if a named family is unavailable.

## Change verification loop

When the audited subject is a code change (a branch, a diff or an uncommitted tree) rather than a running product, verify it in this fixed order and record each step's result. Skipping a step is a reported gap, not a silent omission.

1. **Adversarial verifier** (strongest reasoning model; on Claude-compatible systems the `ver1f1er` agent, Opus). Give it the change, the binding rules (`CLAUDE.md`, `DESIGN.md`, this skill's `design-rules.md`) and the primary sources behind every claim the change makes (product code, API contracts, copy sources). Its job is to refute: every stated fact traced to a source, every translation checked against the original and the file's existing terms, every grid or layout counted, every stale comment flagged. It must label each item verified / refuted / could not verify.
2. **Second model family** when the change is externally visible or touches more than 10 files (orchestration trigger 1 or 3): an independent reviewer from a different model family (on Claude-compatible systems the `c0dex` agent running `codex exec review`). It runs in addition to step 1, never instead of it. "No actionable regressions" from a second family is confirmation of step 1's coverage, not of the change's product correctness.
3. **Build, tests and measurement** by the orchestrator, not by a worker's claim: type check, lint, unit tests, a production build for every deployment variant, and for interface changes the mobile-first measurement in `design-rules.md` (375 px, then desktop; overflow, horizontal scroll, touch targets, wrapped headings, section height) in every shipped language.
4. **Fix and re-verify.** Findings go to a mechanical editor with exact replacement text; then steps 1 and 3 run again on the result. A fix round without a re-verification is unverified.

Measured on 10 October 2026 across four production landing sites: the adversarial verifier found 22 defects over two rounds (a product-contradicting feature claim, three translation term drifts, a missing visual-regression record) that the second family's review reported as clean. The two reviews are complementary, not interchangeable.
