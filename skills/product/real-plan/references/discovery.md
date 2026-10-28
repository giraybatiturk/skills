> **Local workflow rules:**
> - Measure, do not guess. Use evidence from the repo and the running system. Write "could not measure" when you could not measure.
> - New features continue through the `feature-gate` mode before any code. This mode does not replace that gate.

Resolve the unsettled decisions until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work in small rounds.
- Keep unresolved branches in your own notes.
- Ask only the 1–3 independent questions with settled prerequisites that change the next step most.
- Give short choices and one recommendation for each question.
- Wait for the answers before you ask dependent questions or make detailed plans.
- Do not ask the whole frontier at one time.

Use plain numbered questions. Do not use decorative markers or repeated summaries.
- Reuse known answers.
- A platform-dependent implementation choice comes after the platform is known.
- If that prerequisite is missing, end with the questions. Do not give a speculative schema or a full feature plan.

Finding _facts_ is your job, never the job of the user.
- Use repo and runtime tools directly for bounded facts.
- When an orchestration trigger applies, delegate independent fact-finding through the agent capability of your tool. If agents are not available, run the source tracks in series.
- Do not ask the user for anything that you can verify yourself.
- The _decisions_ belong to the user. Put each unresolved decision to the user and wait.

Discovery is sufficient when the decisions that the selected scope needs are settled.
- Defer unrelated or future branches explicitly. Do not explore every possible branch.
- Continue to the feature gate. Do not ask for a separate confirmation of shared understanding.
- The gate keeps the implementation approval that the user already gave for the same scope.

## `--docs` mode

When `real-plan --docs` is invoked (or the user asks for documentation as you go), every settled decision leaves a trace before the next round:

- **ADR**: one file for each decision in `docs/adr/NNNN-<slug>.md` with Context, Decision, Alternatives considered, Consequences. Number them in the order of settling. Never rewrite an accepted ADR. Supersede it.
- **Glossary**: `docs/glossary.md`, one line for each domain term that the interview showed, in the words of the user. Append. Do not reorder.

Write the files as decisions settle, not at the end. Then an interrupted session still leaves the tree readable. Name each file that you wrote in the summary of the round.

## Durable product context

Use the shared Real Audit `references/product-context.md` contract that the Real Plan entrypoint resolved.
- Reuse the canonical PRODUCT.md. Update it with verified product facts. This durable record is different from the optional `--docs` ADR trail.
- Existing verified answers count. Do not repeat the intake after a Real Start/Audit handoff.
- Obey explicit read-only instructions. Do not change DESIGN.md, unless the user separately authorized it.
- The planning workflow still governs story proposals and implementation approval.
