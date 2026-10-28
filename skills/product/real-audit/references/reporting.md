# Shared audit report

Use the Real evidence-led report format: executive summary, explicit criteria, numbered screenshot findings and three priorities. This is a presentation and heuristic prioritization method. It is not a measured usability score. Do not copy the findings of another product into the current audit.

## The audit reports, it does not design the remedy

An audit establishes what is wrong, how you measured it, whom it affects and who must decide next. It does not design the solution.
- Do not write any of these into a finding:
  - a fix
  - a replacement component
  - a colour or typography choice
  - a proposed release scope
  - a pricing structure
  - an experiment design
- Do not add one as an "obvious" aside.
- The reader owns the remedy. If you supply one, a measurement becomes an opinion. A disputed solution can then discredit a sound finding.

Two things are not remedies. Keep them in the finding:
- **How you would verify that the finding is resolved.** State it as an observable outcome. Do not state an implementation.
- **What evidence is still missing and who can supply it.**

Naming the mechanism of a defect is description. It is not design.
- "The top bar does not wrap, so the button sits 20px outside the viewport" is a finding.
- "Give the top bar flex-wrap" is a remedy. It belongs to the reader.

If the user separately asks for remedies, deliver them in a clearly labelled section outside the findings. Or deliver them in a planning workflow such as `real-plan`. Then measurement and proposal never blur.

## Layered delivery

When permitted, keep all in-scope findings and evidence in one local report. Use `docs/audits/YYYY-MM-DD-<slug>.md` in the current project, unless the user names another place.
- In chat, lead with the conclusion, the most important impacts (up to five visible items) and a report link.
- If you can use chat only, compress the sections. Do not drop material findings or evidence boundaries.
- Do not repeat coverage, findings and next actions as multiple closing lists.
- End with one next action if needed.
- Never omit critical findings for brevity. Never prescribe work that the agent can already complete.

## Priority and evidence are separate

- **High:** serious loss of effectiveness, or an important outcome is blocked. Address first.
- **Medium:** meaningful friction, longer task completion or recurring confusion, while the outcome stays achievable.
- **Low:** limited-impact polish or an improvement opportunity.

Explain the observed user and business impact behind the label.
- Priority is an expert judgment. It is not a numerical measurement.
- Do not infer priority from visual taste or speculative revenue alone.
- List and count verified defects separately from opportunities and hypotheses.
- Missing access is unverified coverage. It is not a defect.

A missing attribute or feature is an observation. It is not automatically a verified defect.
- Before you count a defect, establish that its requirement or standard applies to this product and surface.
- If applicability is unresolved, keep it a hypothesis. Identify the decision that you need.
- Preserve every condition in the finding and in the validation decision rule. For example, an empty email submission is a defect only if email is required.
- Before you send, cross-check the summary counts, the findings and the validation tasks for lost conditions.

Keep the technical severity when relevant: P0 = High plus **Critical blocker**, P1 = High, P2 = Medium, P3 = Low.
- Security, safety, data-loss and payment failures must not disappear in the three-label summary.
- A critical blocker takes precedence over totals or an aggregate score.
- Do not turn every payment-related issue into a blocker automatically. Use the demonstrated impact and the applicable mode criteria.

## Screenshot and coverage contract

For an interface audit, inventory every in-scope screen, state, tab, modal, drawer and collapsed container. Open and inspect them in the running product.
- Capture each inspected screen or state. Link the coverage row to its actual image.
- Include device/browser, OS, build/revision and relevant configuration.
- For native mobile evidence, use a native Simulator or device. A browser recreation is not equivalent.

For each visual finding, show or link a numbered screenshot that marks the relevant area.
- When a browser or an image tool is available, this is the default. Make it with the method in Annotated evidence below.
- Use text labels and also colour.
- If annotation is not available, preserve the original capture and describe the exact area.
- Never fabricate or regenerate a screenshot as evidence.
- Reuse a capture for multiple findings on the same state to control cost.
- Keep captures local. Do not upload them without authorization.
- Redact secrets and personal data in report copies. Preserve the integrity of the evidence.

If a runtime, a state, or a capture is not available, record **Unverified** and the missing verifier.
- Supplied screenshots support only the states that they show.
- Static captures cannot verify animations, interrupted actions or frame delivery. For those, follow `motion.md`.
- Nonvisual findings use source, traces, logs or data instead. Mark screenshots not applicable, with a reason.

### Annotated evidence

Use this method for every interface finding when a browser or an image tool is available. The marks locate the finding. They do not argue it. Do not draw anything that you did not measure. When no tool is available, use the fallback above: keep the original capture and describe the exact area.

`scripts/annotate-evidence.mjs`, in the folder of this skill, does steps 2 to 5 for web and native captures. It also does step 1 for a web page: `node <skill>/scripts/annotate-evidence.mjs <spec.json> --out <report folder>/evidence`.
- The spec lists these items for each finding:
  - the capture (a URL with viewport and optional steps, or an existing image)
  - the target boxes (a selector, a text, or image coordinates)
  - the finding ID and the label
- The header of the script documents the spec and the exit codes.
- The script writes `original/`, `marked/`, `contact-sheet.png` and `manifest.json` (every measured box in capture pixels).
- The script opens its own headless browser. It never drives the live browser of the user.
- The script needs Node 20+. It reuses the Playwright and Chromium install of `real-check` when that skill is next to this one (`../real-check`, or `../../engineering/real-check` in the repository layout). It can also use an install in the current folder.
- If the script reports that Playwright or Chromium is missing, install them only where installing is permitted, as `real-check` does. Otherwise use the fallback. Say why under Method and environment.

1. **Capture.** Take each inspected state at a fixed viewport. Keep the web device scale at 1, unless the finding concerns another scale.
   - Native captures come from the Simulator or device at its own scale.
   - The capture is the original. Store it unchanged. No later step edits it, overwrites it or replaces it with a regenerated image.
   - Record device, browser, OS and revision as above.
2. **Locate.** Measure the exact element that each finding is about. Never place a box by eye.
   - On the web, take its bounding box in the page. Use the selector, or the smallest visible element that contains a given text.
   - On native, take the frame of the element from the view or accessibility inspector. Convert it to image pixels (points times the screenshot scale). Or measure it on the image.
   - Stop the run if a target is not found, matches several elements, is hidden, has no size, or is outside the capture. Correct the spec. Do not draw a guessed box.
   - Scroll an element below the fold into view and capture again. Or capture the full page.
   - When running past the edge is itself the finding, mark the visible part. Say in the finding that the rest is outside.
3. **Mark.** Draw on a copy of the capture. Never draw on the original.
   - Draw a red outline 3 px outside each box.
   - Add a red label chip with white bold text. It names the finding ID and the defect as observed, for example `A-07 tabs do not switch`.
   - The label is Fact. A cause that you only infer belongs in the finding text, marked Inference. A remedy belongs nowhere here.
   - Put the chip above its box, else below it, else inside it. Never put it over another label or outline. Never put it past the image edge.
   - Two boxes for one finding can carry their own labels.
   - Every box has a chip with text, so colour never carries the meaning alone.
4. **Crop.** Crop around the marked area with a margin, so the surroundings show. Crop the whole screen only when the finding is about the whole screen.
   - You can enlarge a small crop, such as a phone screen, so the label stays legible. Record the factor.
   - The enlargement resamples the capture. Do not add anything to it. Do not retouch it.
5. **Check the contact sheet.** Put every marked crop on one contact sheet (the script writes it). Look at it before the report is final. A clean exit code does not replace looking. For each crop, verify these items:
   - The box is around the element that the finding names, and not a neighbour.
   - The label is complete and readable. The crop does not cut it off.
   - No two labels or outlines overlap.
   - The content that the finding depends on is still visible.
   - The ID and the label match the report.

   The sheet shows reduced crops and states the scale. Open the crop itself to read small text.
6. **Fix and check again.** Correct what is wrong in the spec. Examples: a box, a missing scroll step, a label that is too long or collides. Look at the new sheet. Repeat until it is clean.
   - This check has caught these failures: two labels printed over each other when two boxes were close together.
   - A box for an element that was below the fold in the capture. You had to scroll it into view and capture again.
   - A label wider than the crop, cut off at its edge.
   - Image files that were never written, because a screenshot tool ignored its output path.
   - Verify that every image that the report names exists on disk. The script checks that each file it writes exists, is not empty and decodes.
7. **Embed under each finding.** Place the marked crop under the finding that it belongs to, next to a link to the original. Do this in the markdown and in any HTML copy. Use paths relative to the report folder.
   - The Evidence line of the finding cites the image. It states what you measured (the box and the capture state) from `manifest.json`. Do not retype it.
   - Several findings on one state share one original. Each gets its own crop.

Marked crops are report copies. Apply the redaction rule above to them before they leave the local folder. Keep the unredacted originals local. The script does not redact.
- A capture step (click, hover, scroll) only reaches a state to photograph.
- On a live product, follow `live-audit.md`. Take no step that changes data. State that each web capture is a page view of that site.
- When an original already exists and the new capture is different, the script refuses to replace it unless you run it with `--recapture`. A recapture is a new capture of the product. Record its time.

## Report order

1. **Executive summary:** selected scope, top impacts, counts of High/Medium/Low verified findings, separate critical blockers and opportunities. Calculate counts from the actual finding list.
2. **Method and environment:** inspected revision, devices, criteria, assumptions and evidence limits.
   - For UX, consider these ten usability heuristics:
     - status visibility
     - understandable real-world language
     - user control
     - consistency/platform conventions
     - error prevention
     - recognition over recall
     - flexibility/efficiency
     - minimal design
     - error diagnosis/recovery
     - help/documentation
   - Use the DESIGN.md of the project and the applicable platform requirements as canonical rules.
   - Heuristics are inspection prompts. They are not invented compliance thresholds.
3. **Coverage:** `Screen/journey | State/container | Verified / Failed / Unverified / Not applicable | Evidence | Limitation/reason`. Keep these statuses separate in totals. If required evidence is missing, the audit is incomplete.
4. **Numbered findings:** group by user journey. Rank by priority within each group. Use the template below. Keep the mode-specific fields where useful.
5. **Open items:** missing evidence, unresolved applicability questions and the decision owner for each. State what remains unknown. Do not turn this section into a fix list.
6. **Validation tasks:** bounded evidence-gathering assignments, linked to the most decision-relevant unresolved findings or stories. Follow the contract below. If none are needed, say so briefly. Do not invent homework. Do not start implementation without applicable user authorization. Previous explicit authorization stays valid.

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

Do not produce an arbitrary score out of 100. If a numeric rubric is explicitly required, do these steps:
1. Establish its anchors, weights and handling of missing evidence first.
2. Label it heuristic.
3. Keep priority and coverage alongside it.

This format alone does not establish release readiness.

## Validation tasks

End the report with a small, prioritized set of actionable assignments when user research or other unavailable evidence could change a material decision.
- Reuse existing evidence before you request new work.
- Keep assignments within the selected audit scope and the available time, access and budget of the user.
- Do not assign routine checks that the agent can already complete within its authorization.
- Avoid a generic checklist. Avoid one task per finding. Combine related unknowns. Explain which decision each task will resolve.

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

Choose the method and sample for the question.
- For one reasonably homogeneous target segment and a narrow formative usability round, five participants can be a proposed starting point. State the limitation: the purpose is to discover friction. It is not to prove coverage or to estimate population rates.
- Do not make five a universal requirement or guarantee.
- Materially different roles, accessibility needs and journeys each need their own coverage rationale.
- Pricing, conversion uplift or market-demand claims need an appropriate research or experimental design. Five opinions do not validate a price. They do not establish statistical significance.
- If baseline, variance, effect-size or recruitment inputs are missing, request those inputs. Or mark the sample decision unresolved. Do not invent precision.

Give participants a realistic outcome such as "Schedule an appointment for next week". Do not use "Tap the plus button and select a date."
- Observe before you help. Record when help was given.
- Separate what participants did from what they said and from the interpretation of the evaluator.
- Use anonymized IDs and disposable data. Obtain participant consent for recordings.
- Proposing the assignment does not authorize recruiting or messaging people, scheduling sessions, paid testing or launching experiments.

Save tasks in the same local audit report, or in the existing research-task location of the project. Link them by stable IDs. A proposal is not a completed study. Use the workflow status Proposed / In progress / Completed / Deferred. Keep it separate from the conclusion.

When results return, review the actual notes or data and the sample conditions before you update the linked finding. Use one of these: **Supported / Contradicted / Inconclusive**. Qualify it to the inspected sample and conditions.
- Preserve the earlier hypothesis. Add a dated evidence/result entry. Do not rewrite history silently.
- Revisit priority only when the evidence warrants it. Do not generalize a small sample to all users.
- Update coverage statuses only for criteria that the new evidence actually addresses.
- Findings that remain uncertain stay unverified. Completed homework alone never establishes release readiness.
- Carry selected results into planning when the user requests it. Do not auto-edit product/design policy or implementation.

## Optional handoff

Use this rule when a confirmed defect is in a web user flow and `real-test` is in the skill catalog of the client. End the report with one line: "Next, optional: once fixed, `real-test` can keep a regression test for this flow."
- If `real-test` is not installed, skip this silently.
- Never invoke it. Never ask the user to install it.
