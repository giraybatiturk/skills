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
