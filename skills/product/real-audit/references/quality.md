# Quality and reliability audit mode

Use for a bounded question about whether an existing change, flow, or module meets its acceptance criteria and remains correct under failure. Resolve the target from the request and project context; do not silently expand to the entire product.

The audit produces evidence and a local report. It does not authorize implementation edits, external writes, paid builds, release, or deployment. Existing applicable authorization remains valid. Run checks only in an appropriate local or isolated test environment; do not exercise destructive, payment, notification, or personal-data mutations against live systems without explicit authorization for those actions.

## Establish the contract

1. Identify the expected outcome from approved acceptance criteria, domain rules, API/schema contracts, and project documentation. Record conflicting sources; implementation or an existing test is not automatically the intended behavior.
2. Define the in-scope journeys and failure cases, including the critical user outcome and any data or authorization invariant. Explain why each matters. Do not invent an acceptance target or treat a suggested improvement as an existing requirement.
3. Map each criterion to implementation, available tests, and observable runtime evidence. Record the target revision, environment, fixture/data conditions, and check command or reproduction steps.

If the intended behavior is unknown, report the missing decision and its owner. Continue independent checks whose contracts are known; do not grade the unknown behavior as correct or broken.

## Inspect the applicable failure paths

Evaluate applicability before testing. These are prompts to investigate, not requirements to add features that the product does not promise:

- **Critical paths and contracts:** successful outcome, boundary inputs, invalid responses, permission/entitlement boundaries, persistence, and compatibility between relevant callers and implementations.
- **State transitions:** enter, complete, cancel, leave, and re-enter; repeated actions; refresh and stale state; account or tenant changes where supported. Verify counters and caches against their actual semantics.
- **Offline, retry, and interruption:** loss of connectivity, timeout, interrupted startup or save, partial success, reconnect, duplicate requests, and retry exhaustion. Check that displayed status matches durable state and that recovery does not duplicate or discard an operation.
- **Concurrency and lifecycle:** overlapping edits, out-of-order responses, navigation during work, restart, and background/foreground transitions where applicable. Check whether prior work can overwrite newer state or leak across contexts.
- **Data loss and recovery:** failed writes, migrations, deletion, rollback, and restoration where the product supports them. Use disposable fixtures or isolated copies. Report an unavailable safe test environment as unverified instead of touching live data.

## Assess test quality

Read the assertions and setup for the relevant tests, not just their names or pass counts. Ask whether they would detect the specific failure under review:

- Do assertions verify a user outcome or invariant, including persisted effects and meaningful negative paths?
- Do fixtures and mocks preserve the contract being tested, or bypass the boundary where the defect could occur?
- Are errors, timing, and asynchronous completion actually observed rather than swallowed or skipped?
- Are checks reproducible under stated conditions, with isolated data and explicit cleanup? Record flaky, skipped, and inconclusive checks separately.

Distinguish test evidence from runtime evidence. A passing unit test establishes only its asserted behavior under its setup. A missing test is a verification gap, not proof of a product defect. Do not invent coverage percentages or infer journey coverage from the number of tests. Report existing coverage measurements only with their actual tool, scope, revision, and limitations.

Run the smallest relevant existing checks that can establish the claimed result. Broaden only for changed dependencies, failures, or unresolved risks. Proposed tests belong in the report until implementation is authorized. Do not rewrite tests merely to match the implementation or weaken an assertion to obtain a pass.

## Evidence and verdict

Before closing an authorized change, compare the actual diff (including relevant new/untracked files) with the agreed intent and acceptance criteria. Explain why each changed area is necessary. Flag unrelated edits, dependency additions, API changes or configuration changes for justification or a proposed separate change. File names and diff size are signals, not proof that an edit is unrelated. Preserve pre-existing work; do not revert, split, stage or commit merely because an audit flags scope growth.

When improving an evaluation or skill, retain the failing scenario and rerun it after the narrow correction, alongside relevant regression and negative cases. Keep mechanical checks separate from semantic judgment; the producer's self-score cannot establish improvement. Report catalog, tool, model and environment differences that prevent causal comparison.

Give every acceptance criterion or applicable scenario one status:

- **Verified:** observed evidence satisfies the stated criterion under recorded conditions.
- **Failed:** observed evidence contradicts that criterion; include a reproducible trigger and impact.
- **Unverified:** a required contract, environment, fixture, check, or observation is unavailable or inconclusive; identify what is missing and who or what can verify it.
- **Not applicable:** explain why the scenario falls outside this product's behavior or the agreed audit scope.

Keep these statuses separate in totals. A code inspection, mock-only test, or successful build must not be presented as an end-to-end result. Scope a positive verdict to the criteria actually verified. If required evidence is missing, the verdict is incomplete; if a criterion fails, identify the failure even when other coverage remains incomplete. Do not claim zero defects, complete coverage, or release readiness beyond the evidence. An audit verdict grants no release authority.

## Deliverable

Use a concise chat report or the project's existing local audit-documentation location when a full document is needed. Include:

1. Target, expected behavior, audit scope, and evidence conditions.
2. Criteria/scenarios mapped to evidence and one of the four statuses.
3. Verified defects ranked by observed user impact, with source location, trigger, expected/actual result, and proposed fix.
4. Test-quality gaps and proposed checks, separated from product defects.
5. Remaining evidence or decisions needed, with verifier/owner and the next bounded check.

Write only a local report unless a specific external publication or issue-tracker action is authorized. If the request requires deeper product direction, interface review, performance measurement, or new implementation scope, identify that boundary and use the relevant Real mode or planning workflow within the user's authorized scope.
