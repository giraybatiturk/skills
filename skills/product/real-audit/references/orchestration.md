# Orchestration rules

Use one agent by default. Split the work when any condition is true:

1. The action is irreversible or externally visible: publishing, deletion, payment, email, messaging, or release.
2. It changes identity, authorization, payment, or personal-data behavior.
3. More than 10 files or more than two repositories are affected.
4. The decision depends on third-party behavior, current external documentation, pricing, policy, or provider limits.
5. The user explicitly asks for orchestration, parallel work, or independent reviews.

For triggered work, use at least two independent perspectives that do not see each other's conclusions. Then use one adversarial verifier. The verifier must be at least as capable as the strongest producer that it verifies.

## Execution contract

Before dispatch, give each worker these five items: a bounded responsibility, permitted files and resources, necessary context, expected output and observable acceptance criteria.
- Workers that share a checkout must preserve each other's changes.
- Independent assessments must not receive each other's conclusions before synthesis.

Record the actual dispatch handle and the terminal result.
- A planned assignment is not completed evidence. A claim of a worker is not completed evidence.
- Verify the deliverable itself against its acceptance criteria.
- Separate the passed, failed and unverified results.
- Resolve conflicting evidence explicitly.

Keep retries bounded.
- After two failures on the same subtask, reassess the cause, the tools or the decomposition before another attempt.
- Do not switch providers silently. Do not expand permissions. Do not spend on a paid fallback.
- A timeout in observation is not a process failure. Inspect the original live handle before you restart.
- Use the native agent tools that are available. Do not build a second execution layer without need.

If delegation is not available, disclose the limitation. Do the useful authorized work in series. Do not pretend that independent verification occurred.
- No model tier name overrides the available models or the choice of the user.
- Apply the same capability requirement to the final verifier, also when the strongest producer is a newer model family.

Choose models by capability, not a pinned version:

| Work | Capability |
|---|---|
| Product architecture and synthesis | strongest available reasoning/product model |
| Adversarial verification | strongest available reasoning model |
| Broad implementation | comprehensive coding model |
| UI/product implementation | balanced coding and visual-reasoning model |
| Mechanical edits and discovery | fastest capable model |

On Codex, the usual mapping is:
- Astra for architecture and verification
- Sol for broad implementation
- Terra for UI and product work
- Luna or Spark for mechanical discovery

On Claude-compatible systems, prefer these:
- the highest product/architecture tier available (including Fable when offered)
- Opus for verification
- Sonnet for implementation
- Haiku for discovery

Fall back by capability if a named family is not available.
