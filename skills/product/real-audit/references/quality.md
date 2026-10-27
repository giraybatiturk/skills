# Quality and reliability audit mode

Use this mode for a bounded question: does an existing change, flow, or module meet its acceptance criteria, and does it stay correct under failure? Resolve the target from the request and the project context. Do not expand silently to the entire product.

The audit produces evidence and a local report. It does not authorize implementation edits, external writes, paid builds, release, or deployment. Existing applicable authorization stays valid.
- Run tests only in an appropriate local or isolated test environment.
- Do not run destructive, payment, notification, or personal-data mutations against live systems without explicit authorization for those actions.

## Establish the contract

1. Identify the expected outcome from approved acceptance criteria, domain rules, API/schema contracts, and project documentation.
   - Record conflicting sources.
   - The implementation or an existing test is not automatically the intended behavior.
2. Define the in-scope journeys and failure cases. Include the critical user outcome and any data or authorization invariant. Explain why each one matters.
   - Do not invent an acceptance target.
   - Do not treat a suggested improvement as an existing requirement.
3. Map each criterion to the implementation, the available tests, and the observable runtime evidence. Record the target revision, the environment, the fixture and data conditions, and the test command or reproduction steps.

If the intended behavior is unknown, report the missing decision and its owner. Continue the independent tests whose contracts are known. Do not grade the unknown behavior as correct or broken.

## Inspect the applicable failure paths

Evaluate applicability before you test. These are prompts to investigate. They are not requirements to add features that the product does not promise:

- **Critical paths and contracts:** successful outcome, boundary inputs, invalid responses, permission/entitlement boundaries, persistence, and compatibility between relevant callers and implementations.
- **State transitions:** enter, complete, cancel, leave, and re-enter; repeated actions; refresh and stale state; account or tenant changes where supported. Verify counters and caches against their actual semantics.
- **Offline, retry, and interruption:** loss of connectivity, timeout, interrupted startup or save, partial success, reconnect, duplicate requests, and retry exhaustion.
  - Verify that the displayed status matches the durable state.
  - Verify that recovery does not duplicate or discard an operation.
- **Concurrency and lifecycle:** overlapping edits, out-of-order responses, navigation during work, restart, and background/foreground transitions where applicable. Verify if prior work can overwrite newer state or leak across contexts.
- **Data loss and recovery:** failed writes, migrations, deletion, rollback, and restoration where the product supports them. Use disposable fixtures or isolated copies. If no safe test environment is available, report it as unverified. Do not touch live data.

## Assess test quality

Read the assertions and the setup of the relevant tests. Do not read only their names or pass counts. Ask whether they would detect the specific failure under review:

- Do assertions verify a user outcome or invariant, including persisted effects and meaningful negative paths?
- Do fixtures and mocks keep the contract that you test? Or do they bypass the boundary where the defect could occur?
- Does the test actually observe errors, timing, and asynchronous completion? Or does it swallow or skip them?
- Can you reproduce the tests under stated conditions, with isolated data and explicit cleanup? Record flaky, skipped, and inconclusive tests separately.

Distinguish test evidence from runtime evidence.
- A passing unit test establishes only its asserted behavior under its setup.
- A missing test is a verification gap. It is not proof of a product defect.
- Do not invent coverage percentages. Do not infer journey coverage from the number of tests.
- Report existing coverage measurements only with their actual tool, scope, revision, and limitations.

Run the smallest relevant existing tests that can establish the claimed result.
- Broaden only for changed dependencies, failures, or unresolved risks.
- Proposed tests stay in the report until implementation is authorized.
- Do not rewrite tests only to match the implementation. Do not weaken an assertion to get a pass.

## Evidence and verdict

Before you close an authorized change, compare the actual diff (including relevant new and untracked files) with the agreed intent and acceptance criteria.
- Explain why each changed area is necessary.
- Flag unrelated edits, dependency additions, API changes or configuration changes. Ask for a justification, or propose a separate change.
- File names and diff size are signals. They are not proof that an edit is unrelated.
- Preserve pre-existing work. Do not revert, split, stage or commit only because an audit flags scope growth.

When you improve an evaluation or skill, keep the failing scenario. Run it again after the narrow correction, together with the relevant regression and negative cases.
- Keep mechanical tests separate from semantic judgment. The self-score of the producer cannot establish improvement.
- Report the catalog, tool, model and environment differences that prevent a causal comparison.

Give every acceptance criterion or applicable scenario one status:

- **Verified:** observed evidence satisfies the stated criterion under the recorded conditions.
- **Failed:** observed evidence contradicts that criterion. Include a reproducible trigger and the impact.
- **Unverified:** a required contract, environment, fixture, test, or observation is not available or inconclusive. Identify what is missing and who or what can verify it.
- **Not applicable:** explain why the scenario is outside the behavior of this product or the agreed audit scope.

Keep these statuses separate in totals.
- Do not present a code inspection, a mock-only test, or a successful build as an end-to-end result.
- Scope a positive verdict to the criteria that you actually verified.
- If required evidence is missing, the verdict is incomplete.
- If a criterion fails, identify the failure, also when other coverage remains incomplete.
- Do not claim zero defects, complete coverage, or release readiness beyond the evidence.
- An audit verdict gives no release authority.

## Deliverable

Use a concise chat report. Or, when you need a full document, use the existing local audit-documentation location of the project. Include:

1. Target, expected behavior, audit scope, and evidence conditions.
2. Criteria/scenarios mapped to evidence and one of the four statuses.
3. Verified defects ranked by observed user impact, with source location, trigger and expected/actual result. Report the defect, not its correction.
4. Test-coverage gaps, separated from product defects. Name the untested behavior and its risk. Do not name the test to write.
5. Remaining evidence or decisions needed, with the verifier or owner and the next bounded test.

Write only a local report, unless the user authorized a specific external publication or issue-tracker action. If the request needs deeper product direction, interface review, performance measurement, or new implementation scope, identify that boundary. Use the relevant Real mode or planning workflow within the authorized scope of the user.
