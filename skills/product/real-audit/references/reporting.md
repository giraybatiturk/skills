# Shared audit report

Use the Real evidence-led report format: executive summary, explicit criteria, numbered screenshot findings, three priorities and separate recommendations. This is a presentation and heuristic prioritization method, not a measured usability score or permission to implement recommendations. Do not copy another product's findings into the current audit.

## Layered delivery

Keep full in-scope findings and evidence in one local report when permitted. Chat leads with the conclusion, the most important impacts (up to five visible items) and a report link. If chat-only, compress the sections without dropping material findings or evidence boundaries. Do not repeat coverage, findings and next actions as multiple closing lists. End with one next action if needed. Never omit critical findings for brevity or prescribe work the agent can already complete.

## Priority and evidence are separate

- **High / Yüksek:** serious loss of effectiveness or an important outcome blocked; address first.
- **Medium / Orta:** meaningful friction, longer task completion or recurring confusion while the outcome remains achievable.
- **Low / Düşük:** limited-impact polish or an improvement opportunity.

Explain the observed user/business impact behind the label. Priority is an expert judgment, not a numerical measurement. Do not infer priority from visual taste or speculative revenue alone. Verified defects and opportunities/hypotheses must be listed and counted separately; missing access is unverified coverage, not a defect.

A missing attribute or feature is an observation, not automatically a verified defect. Before counting a defect, establish that its requirement or standard applies to this product and surface. If applicability is unresolved, keep it a hypothesis and identify the decision needed. Preserve every condition in the recommendation and validation decision rule: for example, an empty email submission is a defect only if email is required. Before sending, cross-check summary counts, findings and validation tasks for lost conditions.

Retain technical severity when relevant: P0 = High plus **Critical blocker**, P1 = High, P2 = Medium, P3 = Low. Security, safety, data-loss and payment failures must not disappear in the three-label summary. A critical blocker takes precedence over totals or an aggregate score. Do not automatically turn every payment-related issue into a blocker; use demonstrated impact and applicable mode criteria.

## Screenshot and coverage contract

For an interface audit, inventory every in-scope screen, state, tab, modal, drawer and collapsed container. Open and inspect them in the running product. Capture each inspected screen/state and link the coverage row to its actual image. Include device/browser, OS, build/revision and relevant configuration. Use a native Simulator/device for native mobile evidence; a browser recreation is not equivalent.

For each visual finding, show or link a numbered screenshot marking the relevant area when tools permit. Use text labels as well as colour. If annotation is unavailable, preserve the original capture and describe the exact area. Never fabricate or regenerate a screenshot as evidence. Reuse a capture for multiple findings on the same state to control cost. Keep captures local; do not upload them without authorization. Redact secrets/personal data in report copies while preserving evidence integrity.

If runtime, a state, or a capture is unavailable, record **Unverified** and the missing verifier. Supplied screenshots support only the states they show. Static captures cannot verify animations, interrupted actions or frame delivery; follow `motion.md` for those. Nonvisual findings use source, traces, logs or data instead; mark screenshots not applicable with a reason.

## Report order

1. **Executive summary:** selected scope, top impacts, counts of High/Medium/Low verified findings, separate critical blockers and opportunities. Calculate counts from the actual finding list.
2. **Method and environment:** inspected revision, devices, criteria, assumptions and evidence limits. For UX, consider these ten usability heuristics: status visibility; understandable real-world language; user control; consistency/platform conventions; error prevention; recognition over recall; flexibility/efficiency; minimal design; error diagnosis/recovery; help/documentation. Use project DESIGN.md and applicable platform requirements as canonical rules. Heuristics are inspection prompts, not invented compliance thresholds.
3. **Coverage:** `Screen/journey | State/container | Verified / Failed / Unverified / Not applicable | Evidence | Limitation/reason`. Keep these statuses separate in totals. Required missing evidence means an incomplete audit.
4. **Numbered findings:** group by user journey and rank by priority within it. Use the template below and retain mode-specific fields where useful.
5. **Next actions:** proposed fixes, research/experiments, and missing evidence.
6. **Validation tasks / Doğrulama görevleri:** bounded evidence-gathering assignments linked to the most decision-relevant unresolved findings or stories, following the contract below. If none are needed, say so briefly instead of inventing homework. Do not start implementation without applicable user authorization; previous explicit authorization remains valid.

```text
[A-01] Short title | High / Medium / Low | Critical blocker: yes/no
Type: Verified defect / Opportunity-hypothesis
Criterion: applicable heuristic, product contract or documented rule
Context: screen/flow, state, device/OS, revision
Evidence: numbered screenshot or source/trace/data reference
Observed: reproducible trigger and actual behavior
Impact: affected user outcome; distinguish observed from inferred impact
Recommendation: separate, concrete proposed change or investigation
Verification: how to check the recommendation if implementation is authorized
```

Do not produce an arbitrary score out of 100. If a numeric rubric is explicitly required, establish its anchors, weights and missing-evidence handling first, label it heuristic, and retain priority and coverage alongside it. This format alone does not establish release readiness.

## Validation tasks

End the report with a small, prioritized set of actionable assignments when user research or other unavailable evidence could change a material decision. Reuse existing evidence before requesting new work. Keep assignments within the selected audit scope and the user's available time, access and budget. Do not assign routine checks the agent can already complete within its authorization. Avoid a generic checklist or one task per finding; combine related unknowns and explain which decision each task will resolve.

Every task needs:

```text
[V-01] Task title
Related finding/story: existing IDs
Question or hypothesis: what remains uncertain and why it matters
Method: usability observation / interview / analytics check / controlled experiment / other justified method
Participants or data: relevant user segment and recruitment criteria, or exact data/cohort required
Scope: proposed participant count or data window, with rationale and limits
Setup: product revision, device/context, starting state and suitable test data
Task prompt: neutral user goal; no button names, prescribed navigation or hints
Evidence to record: completion without help, assistance, errors, hesitation and recovery; timing only when relevant and consistently measured
Decision rule: how each possible result would change the finding or next action
Owner and effort: known owner or Unassigned; user-provided constraints or explicitly labeled estimates, never invented commitments
Return format: anonymized observation rows plus evidence references
```

Choose the method and sample for the question. For one reasonably homogeneous target segment and a narrow formative usability round, five participants may be a proposed starting point, with an explicit limitation that the purpose is discovering friction, not proving coverage or estimating population rates. Do not make five a universal requirement or guarantee. Materially different roles, accessibility needs and journeys require their own coverage rationale. Pricing, conversion uplift or market-demand claims need an appropriate research/experimental design; five opinions do not validate a price or establish statistical significance. If baseline, variance, effect-size or recruitment inputs are missing, request those inputs or mark the sample decision unresolved instead of inventing precision.

Give participants a realistic outcome such as "Schedule an appointment for next week," not "Tap the plus button and select a date." Observe before helping and record when help was given. Separate what participants did from what they said and from the evaluator's interpretation. Use anonymized IDs and disposable data; obtain participant consent for recordings. Proposing the assignment does not authorize recruiting/messaging people, scheduling sessions, paid testing or launching experiments.

Save tasks in the same local audit report or the project's existing research-task location, linked by stable IDs. A proposal is not a completed study. Use workflow status Proposed / In progress / Completed / Deferred separately from the conclusion.

When results return, review the actual notes/data and sample conditions before updating the linked finding: **Supported / Contradicted / Inconclusive** (Doğrulandı / Çürütüldü / Belirsiz kaldı), qualified to the inspected sample and conditions. Preserve the earlier hypothesis and add a dated evidence/result entry rather than silently rewriting history. Revisit priority and proposed action only when the evidence warrants it; do not generalize a small sample to all users. Update coverage statuses only for criteria the new evidence actually addresses. Findings that remain uncertain stay unverified, and completed homework alone never establishes release readiness. Carry selected results into planning when requested; do not auto-edit product/design policy or implementation.
