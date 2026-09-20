# Skills product audit

Date: 2026-09-13. Scope: current local working tree, including uncommitted 0.8.0 consolidation. This is not a review of the published GitHub revision.

## Remediation status

A01-A04 corrected and independently rechecked. A05 resolved by an explicit full-bundle contract, installed dependency resolution, and a shared guarded installer used by restore.sh. Isolated tests passed for fresh/repeated installation, owned legacy links, copied-directory and foreign-link conflicts (no mutations), missing references (failure before mutation), and bootstrap missing-bundle failure. Four skill validators, plugin manifest validation, shell syntax and diff checks passed. Fresh-session model invocation remains unverified. An alternate checkout path pointing through filesystem aliases may be rejected as a foreign link; this is a conservative stop, not automatic replacement. No commit or publication performed.

## Verdict

Four workflows simplify discovery, but packaging validation alone does not establish safe or coherent behavior. Resolve audit-side mutation instructions and contradictory evidence gates before publishing this revision.

## Evidence and limits

Inspected all workflow entrypoints and relevant references, README, manifest, and bootstrap. Two independent reviews covered behavior and packaging; packaging reviewer subsequently checked behavioral candidates adversarially. Plugin strict validation and diff whitespace checks pass. Four entrypoints exist. These checks do not prove fresh-session implicit invocation. No implementation files were changed by this audit.

Could not measure: fresh Claude/Codex natural-language invocation rates, adoption, time saved, false-positive rate, or published revision behavior. Verification owner: maintainer using isolated fresh sessions. No usage telemetry or evaluation corpus was found in the inspected repository.

## Product model and journeys

Promise: users describe product work naturally; the system chooses a compact workflow, gathers evidence, and produces trustworthy decisions. Audience: product leads using coding agents. Return trigger: a feature, product review, or external decision.

| Journey | Current evidence | Status |
|---|---|---|
| Discover four workflows | Four SKILL.md files and valid manifest | Verified statically |
| Natural language selects correct mode | Descriptions and routing instructions exist | Runtime unverified |
| Plan from repository evidence | Read-only instruction conflicts with no-file-open gate | Conflicting |
| Audit without implementation changes | Several references instruct writes | Conflicting |
| Report unavailable evidence honestly | Overall rule exists; mode statuses/score omit it | Incomplete |
| Install only Plan | References require adjacent Audit installation | Dependency gap |

## Findings

### A01 [P1] Review can authorize its own implementation changes

Evidence: `skills/product/real-audit/references/design.md:17` allows direct P0/P1 fixes. `references/module.md:32,39` instructs writing project agent rules and tests during inventory. `references/performance.md:16` writes a budget into DESIGN.md.

Trigger: user asks only to inspect a screen/module. The workflow can modify code or future project policy. Recommendation: audit defaults to report-only; fixes and policy changes require applicable implementation authorization. Owner: skill maintainer. Decision: Now.

### A02 [P2] Planning blocks the reads required to prepare approval

Evidence: `skills/product/real-plan/references/feature-gate.md:5,21` requires read-only inspection, but line 76 forbids opening any file before approval. Recommendation: forbid implementation edits, explicitly permit evidence reads. Owner: skill maintainer. Decision: Now.

### A03 [P2] Missing coverage can be mistaken for a clean audit

Evidence: `references/design.md:65` assigns clean/100 for no findings; line 42 labels high scores ship-ready. Module status at `references/module.md:26` only allows working/half/missing.

Trigger: an authenticated or hidden state cannot be inspected. Recommendation: add unverified/partial coverage states and withhold ship-ready until required measurements exist. Owner: skill maintainer. Decision: Now.

### A04 [P2] Performance verification can undo a successful fix

Evidence: `references/performance.md:105` requires bundle shrink for every fix, although the same reference includes preload, loading-state, and responsiveness improvements.

Trigger: LCP improves while gzip bytes stay constant. Recommendation: compare the metric targeted by each fix and protect other budgets. Owner: skill maintainer. Decision: Now.

### A05 [P2] Installation assumes sibling skills and existing symlinks

Evidence: `skills/product/real-plan/SKILL.md:16,18` references sibling Audit files. `README.md:59` uses ln -sfn without handling an existing real directory. Packaging reviewer reproduced a nested symlink with the old SKILL.md remaining active in a temporary directory.

Recommendation: declare/resolve the Audit dependency or install the bundle atomically; reject existing copied directories with an actionable migration instruction instead of reporting success. Owner: installer maintainer. Decision: Next.

## Metrics and evaluation

Proposed outcome: correct, evidence-backed completion without unintended mutations. No measured baseline or target is available.

- Routing accuracy = correctly selected workflow and mode / fixed evaluation prompts.
- Evidence honesty = cases correctly marked unverified / cases with deliberately unavailable evidence.
- Audit mutation rate = report-only scenarios that modify implementation or policy / report-only scenarios. Any such case fails that scenario.
- Install integrity = installation scenarios with four resolvable entrypoints and all required references / installation scenarios.

Measure a versioned local evaluation set: new feature, product review, screen-only audit, unavailable credentials, performance improvement without byte reduction, isolated Plan install, copied-directory migration, and repeated setup. Capture client/version, actual invoked skill, result, and changed files. Do not infer model behavior from prose-only routing simulation.

## Monetization and prioritization

No monetization decision is required for this developer-tool audit. Revenue, adoption, and commercial conversion were not measured.

Now: A01-A04 and a small behavioral evaluation set. Next: A05 and fresh-session Claude/Codex evaluation. Later: measured routing tuning. Not doing: more public skills, new model families, or arbitrary quality scores.

## Proposed next release

Objective: make audit and plan behavior internally consistent before distributing 0.8.0.

Acceptance: report-only audits make no implementation/policy edits; plans can read evidence before approval; unmeasured states never receive ship-ready; performance fixes are judged on their target metric; supported installation scenarios resolve all references. Run both fresh-session client evaluations before claiming automatic invocation is verified.

Release guardrail: this report does not authorize commit, push, publication, or changes to external services. Open decision: whether individually installable skills or an all-four bundle is the supported contract.
