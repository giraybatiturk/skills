> **Local workflow rules:**
> - Measure, don't guess: evidence from the repo and the running system; write "could not measure" when you couldn't.
> - New features continue through the `feature-gate` mode before any code; this mode does not replace that gate.

Resolve the unsettled decisions until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work in small rounds. Keep unresolved branches internally, but ask only the 1–3 independent questions with settled prerequisites that most change the next step. Give short choices and one recommendation per question. Wait for their answers before dependent questions or detailed planning. Do not ask the entire frontier at once.

Use plain numbered questions, without decorative markers or repeated summaries. Reuse known answers. A platform-dependent implementation choice belongs after the platform is known. If that prerequisite is missing, end with the questions, not a speculative schema or full feature plan.

Finding _facts_ is your job, never the user's. Use repository and runtime tools directly for bounded facts. When an orchestration trigger applies, delegate independent fact-finding through the current client's agent capability; if agents are unavailable, run the source tracks serially. Do not ask the user for anything you can verify yourself. The _decisions_ are the user's: put each unresolved decision to them and wait.

Discovery is sufficient when decisions needed for the selected scope are settled. Explicitly defer unrelated or future branches; do not explore every possible branch. Continue to the feature gate without a separate confirmation of shared understanding. The gate preserves implementation approval already given for the same scope.

## `--docs` mode

When `real-plan --docs` is invoked (or the user asks for documentation as you go), every settled decision leaves a trace before the next round:

- **ADR**: one file per decision in `docs/adr/NNNN-<slug>.md` with Context, Decision, Alternatives considered, Consequences. Numbered in order of settling; never rewrite an accepted ADR, supersede it.
- **Glossary**: `docs/glossary.md`, one line per domain term the interview surfaced, in the user's words. Append, do not reorder.

Write the files as decisions settle, not at the end: an interrupted session still leaves the tree readable. Mention each file you wrote in the round summary.

## Durable product context

Use the shared Real Audit `references/product-context.md` contract resolved by the Real Plan entrypoint. Reuse and update the canonical PRODUCT.md with confirmed product facts; this durable record is distinct from the optional `--docs` ADR trail. Existing confirmed answers count, so do not repeat the intake after a Real Start/Audit handoff. Preserve explicit read-only instructions and keep DESIGN.md untouched unless separately authorized. Story proposals and implementation approval remain governed by the planning workflow.
