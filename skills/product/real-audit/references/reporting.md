# Shared audit report

Use the Real evidence-led report format: executive summary, explicit criteria, numbered screenshot findings and three priorities. This is a presentation and heuristic prioritization method, not a measured usability score. Do not copy another product's findings into the current audit.

## The audit reports, it does not design the remedy

An audit establishes what is wrong, how it was measured, whom it affects and who must decide next. It does not design the solution. Do not write a fix, a replacement component, a colour/typography choice, a proposed release scope, a pricing structure or an experiment design into a finding, and do not smuggle one in as an "obvious" aside. The reader owns the remedy; supplying one converts a measurement into an opinion and lets a disputed solution discredit a sound finding.

Two things are not remedies and must stay: **how the finding would be verified as resolved**, stated as an observable outcome rather than an implementation, and **what evidence is still missing and who can supply it**. Naming a defect's mechanism is description, not design: "the top bar does not wrap, so the button sits 20px outside the viewport" is a finding; "give the top bar flex-wrap" is a remedy and belongs to the reader.

If the user separately asks for remedies, deliver them as a clearly labelled section outside the findings, or in a planning workflow such as `real-plan`, so measurement and proposal never blur.

## Layered delivery

Keep full in-scope findings and evidence in one local report when permitted. Chat leads with the conclusion, the most important impacts (up to five visible items) and a report link. If chat-only, compress the sections without dropping material findings or evidence boundaries. Do not repeat coverage, findings and next actions as multiple closing lists. End with one next action if needed. Never omit critical findings for brevity or prescribe work the agent can already complete.

## Priority and evidence are separate

- **High:** serious loss of effectiveness or an important outcome blocked; address first.
- **Medium:** meaningful friction, longer task completion or recurring confusion while the outcome remains achievable.
- **Low:** limited-impact polish or an improvement opportunity.

Explain the observed user/business impact behind the label. Priority is an expert judgment, not a numerical measurement. Do not infer priority from visual taste or speculative revenue alone. Verified defects and opportunities/hypotheses must be listed and counted separately; missing access is unverified coverage, not a defect.

A missing attribute or feature is an observation, not automatically a verified defect. Before counting a defect, establish that its requirement or standard applies to this product and surface. If applicability is unresolved, keep it a hypothesis and identify the decision needed. Preserve every condition in the finding and the validation decision rule: for example, an empty email submission is a defect only if email is required. Before sending, cross-check summary counts, findings and validation tasks for lost conditions.

Retain technical severity when relevant: P0 = High plus **Critical blocker**, P1 = High, P2 = Medium, P3 = Low. Security, safety, data-loss and payment failures must not disappear in the three-label summary. A critical blocker takes precedence over totals or an aggregate score. Do not automatically turn every payment-related issue into a blocker; use demonstrated impact and applicable mode criteria.

## Screenshot and coverage contract

For an interface audit, inventory every in-scope screen, state, tab, modal, drawer and collapsed container. Open and inspect them in the running product. Capture each inspected screen/state and link the coverage row to its actual image. Include device/browser, OS, build/revision and relevant configuration. Use a native Simulator/device for native mobile evidence; a browser recreation is not equivalent.

For each visual finding, show or link a numbered screenshot marking the relevant area. When a browser or an image tool is available this is the default, made with the method in Annotated evidence below. Use text labels as well as colour. If annotation is unavailable, preserve the original capture and describe the exact area. Never fabricate or regenerate a screenshot as evidence. Reuse a capture for multiple findings on the same state to control cost. Keep captures local; do not upload them without authorization. Redact secrets/personal data in report copies while preserving evidence integrity.

If runtime, a state, or a capture is unavailable, record **Unverified** and the missing verifier. Supplied screenshots support only the states they show. Static captures cannot verify animations, interrupted actions or frame delivery; follow `motion.md` for those. Nonvisual findings use source, traces, logs or data instead; mark screenshots not applicable with a reason.

### Annotated evidence

Use this method for every interface finding when a browser or an image tool is available. The marks locate the finding; they do not argue it, and nothing is drawn that was not measured. When no tool is available, the fallback above stands: keep the original capture and describe the exact area.

`scripts/annotate-evidence.mjs`, in this skill's folder, carries out steps 2 to 5 for web and native captures alike, and step 1 for a web page: `node <skill>/scripts/annotate-evidence.mjs <spec.json> --out <report folder>/evidence`. The spec lists, for each finding, the capture (a URL with viewport and optional steps, or an existing image), the target boxes (a selector, a text, or image coordinates), the finding ID and the label. The script's header documents the spec and the exit codes. It writes `original/`, `marked/`, `contact-sheet.png` and `manifest.json` (every measured box in capture pixels). It opens its own headless browser and never drives the user's live one. It needs Node 20+ and reuses the Playwright and Chromium install of `real-check` when that skill sits next to this one (`../real-check`, or `../../engineering/real-check` in the repository layout), or one in the current folder. If it reports that Playwright or Chromium is missing, install them only where installing is permitted, as `real-check` does; otherwise use the fallback and say why under Method and environment.

1. **Capture.** Take each inspected state at a fixed viewport; keep the web device scale at 1 unless the finding concerns another scale. Native captures come from the Simulator or device at its own scale. The capture is the original: it is stored unchanged, and no later step edits it, overwrites it or replaces it with a regenerated image. Record device, browser, OS and revision as above.
2. **Locate.** Measure the exact element each finding is about; never place a box by eye. On the web, take its bounding box in the page by selector, or by the smallest visible element that contains a given text. On native, take the element's frame from the view or accessibility inspector and convert it to image pixels (points times the screenshot scale), or measure it on the image. A target that is not found, matches several elements, is hidden or has no size, or lies outside the capture stops the run. Correct the spec; do not draw a guessed box. An element below the fold is scrolled into view and captured again, or the full page is captured. When running past the edge is itself the finding, mark the visible part and say in the finding that the rest lies outside.
3. **Mark.** Draw on a copy of the capture, never on the original: a red outline 3 px outside each box and a red label chip with white bold text that names the finding ID and the defect as observed, for example `A-07 tabs do not switch`. The label is Fact. A cause that is only inferred belongs in the finding text, marked Inference, and a remedy belongs nowhere here. Put the chip above its box, else below it, else inside it, never over another label or outline and never past the image edge. Two boxes for one finding may carry their own labels. Every box has a chip with text, so colour never carries the meaning alone.
4. **Crop.** Crop around the marked area with a margin so the surroundings show; crop the whole screen only when the finding is about the whole screen. A small crop, such as a phone screen, may be enlarged so the label stays legible. Record the factor. The enlargement resamples the capture; nothing is added to it or retouched.
5. **Check the contact sheet.** Put every marked crop on one contact sheet (the script writes it) and look at it before the report is final. A clean exit code does not replace looking. For each crop confirm that the box is around the element the finding names and not a neighbour, that the label is complete and readable and not cut off by the crop, that no two labels or outlines overlap, that the content the finding depends on is still visible, and that the ID and label match the report. The sheet shows reduced crops and states the scale; open the crop itself to read small text.
6. **Fix and check again.** Correct what is wrong in the spec (a box, a missing scroll step, a label that is too long or collides) and look at the new sheet. Repeat until it is clean. Failures this check has caught: two labels printed over each other when two boxes sat close together; a box for an element that was below the fold in the capture, which had to be scrolled into view and captured again; a label wider than the crop, cut off at its edge; and image files that were never written because a screenshot tool ignored its output path. Confirm every image the report names exists on disk; the script checks that each file it writes exists, is not empty and decodes.
7. **Embed under each finding.** Place the marked crop under the finding it belongs to, next to a link to the original, in the markdown and in any HTML copy, with paths relative to the report folder. The finding's Evidence line cites the image and states what was measured (the box and the capture state) from `manifest.json`, not retyped. Several findings on one state share one original and each get their own crop.

Marked crops are report copies. Apply the redaction rule above to them before they leave the local folder, and keep the unredacted originals local; the script does not redact. A capture step (click, hover, scroll) only reaches a state to be photographed. On a live product follow `live-audit.md`: take no step that changes data, and state that each web capture is a page view of that site. When an original already exists and the new capture differs, the script refuses to replace it unless it is run with `--recapture`; a recapture is a new capture of the product, so record its time.

## Report order

1. **Executive summary:** selected scope, top impacts, counts of High/Medium/Low verified findings, separate critical blockers and opportunities. Calculate counts from the actual finding list.
2. **Method and environment:** inspected revision, devices, criteria, assumptions and evidence limits. For UX, consider these ten usability heuristics: status visibility; understandable real-world language; user control; consistency/platform conventions; error prevention; recognition over recall; flexibility/efficiency; minimal design; error diagnosis/recovery; help/documentation. Use project DESIGN.md and applicable platform requirements as canonical rules. Heuristics are inspection prompts, not invented compliance thresholds.
3. **Coverage:** `Screen/journey | State/container | Verified / Failed / Unverified / Not applicable | Evidence | Limitation/reason`. Keep these statuses separate in totals. Required missing evidence means an incomplete audit.
4. **Numbered findings:** group by user journey and rank by priority within it. Use the template below and retain mode-specific fields where useful.
5. **Open items:** missing evidence, unresolved applicability questions and the decision owner for each. State what remains unknown; do not turn this section into a fix list.
6. **Validation tasks:** bounded evidence-gathering assignments linked to the most decision-relevant unresolved findings or stories, following the contract below. If none are needed, say so briefly instead of inventing homework. Do not start implementation without applicable user authorization; previous explicit authorization remains valid.

```text
[A-01] Short title | High / Medium / Low | Critical blocker: yes/no
Type: Verified defect / Opportunity-hypothesis
Criterion: applicable heuristic, product contract or documented rule
Context: screen/flow, state, device/OS, revision
Evidence: numbered screenshot or source/trace/data reference
Observed: reproducible trigger and actual behavior
Impact: affected user outcome; distinguish observed from inferred impact
Decision owner: role or person who decides what happens next; Unassigned when unknown
Resolved when: observable outcome that would show the finding no longer holds, expressed without prescribing an implementation
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
Scope: participant count or data window, with rationale and limits
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

When results return, review the actual notes/data and sample conditions before updating the linked finding: **Supported / Contradicted / Inconclusive**, qualified to the inspected sample and conditions. Preserve the earlier hypothesis and add a dated evidence/result entry rather than silently rewriting history. Revisit priority only when the evidence warrants it; do not generalize a small sample to all users. Update coverage statuses only for criteria the new evidence actually addresses. Findings that remain uncertain stay unverified, and completed homework alone never establishes release readiness. Carry selected results into planning when requested; do not auto-edit product/design policy or implementation.

## Optional handoff

When a confirmed defect is in a web user flow and `real-test` is in the client's skill catalog, end the report with one line: "Next, optional: once fixed, `real-test` can keep a regression test for this flow." Skip silently if it is not installed; never invoke it or ask the user to install it.
