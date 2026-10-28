# Design audit mode

Resolve the target from the scope that the user selected and the available screen, file or route context.
- For an explicitly focused visual request, the shared screenshot or preview route can identify the target. Do not ask again.
- For an ambiguous audit request, use the scope chooser of the entrypoint. An open preview alone does not narrow an explicit full audit.
- Full scope starts with an inventory of all screens and applicable states.

Source of rules: the `DESIGN.md` of the project. If there is none, `design-rules.md` is the baseline. **Never invent a rule.**

For a review of animation, gesture, transition or feedback, read `motion.md` in this folder. Motion belongs to UX/design. Share runtime and interruption evidence with Performance and Quality. Do not duplicate findings.

## Flow

0. Read `reporting.md` and use its screenshot evidence and coverage contract. **Start visual.**
   - Spacing (box-to-box gaps, button padding, edge proximity), alignment, rhythm, colour and radius, states and consistency show only in the render. Static code misses them.
   - The user shares a preview screenshot, or headless capture runs if it is installed. **Do not automate the live browser of the user, unless the user explicitly allows it right then.**
1. Read the screenshot, the target screen (component and its style file) and `DESIGN.md`. **For consistency**, also scan 1-2 sibling screens (same module, or same kind: list / detail / form).
1b. **Branch coverage: enumerate every branch and every collapsed, hidden or nested container.**
   - Branches: tabs, segment modes, conditional renders.
   - Containers that are hidden on open: accordion panels, collapsibles, popover/dropdown/menu contents, modals/drawers, expandable rows, sub-sections.
   - **Open each one and look inside.** Audit each one separately.
   - Give each container a coverage entry: verified, unverified, or not applicable with a reason.
   - Create a finding only for a verified defect. Record missing screenshots or access as unverified coverage.
1c. **Measure the narrow viewport before you judge it.** Render at a real phone width. Take numbers, not impressions.
   - Horizontal overflow is `document.documentElement.scrollWidth - window.innerWidth`. A value above zero means that the page itself scrolls sideways.
   - A table that is wider than the viewport is correct when its own container scrolls and the body does not.
   - Verify that every interactive element sits inside the viewport. An element with `getBoundingClientRect().right` above `window.innerWidth` is unreachable. This is a functional failure. It is not only clipping.
   - Measure hit areas against the guidance of the platform. Do not use a remembered threshold.
   - Then repeat at desktop width.

   Practical note: resizing a browser window does not always resize the viewport of the page, especially after the tab was wide. Confirm the effective `window.innerWidth` before you trust a measurement that you took after a resize.

2. Audit **big picture → detail** (block frames before pixels):
   Order of attack: purpose and IA first. Then layout and action priority, then the component cascade, then tokens. Then the nine dimensions below, one by one. Structure before pixels.
   - If there is a structural problem higher up, **flag it first**. Do not drown in pixel and token detail.
   - Every finding has six items:
     - `file:line`
     - dimension
     - priority (High/Medium/Low)
     - critical-blocker flag, when applicable
     - the applicable DESIGN.md or baseline section that it violates
     - a one-sentence problem
   - Describe the defect and its mechanism. Do not design the correction.
3. **Adversarially verify** every finding that you are not sure of. Read the line. Kill false positives.
   - Is the hex in a comment?
   - Is it a `var(--*)`?
   - Is the translate an active state or a hover?
   - Is the native element a slot or a real control?
4. Report the verified findings and the coverage.
   - Mark each visual finding on its capture with the annotated evidence method in `reporting.md`. Use the boxes that you measured above.
   - Score only under the conditions below.
5. **Report; do not design the correction.**
   - Severity does not authorize edits. An audit does not produce the replacement layout, component, token or colour choice.
   - State what breaks, against which rule, and the observable outcome that would show it resolved.
   - If the user separately authorizes fixes, do that work as a labelled task outside the findings. Compare the measured coverage and the screenshots before and after.

## Dimensions

Use the DESIGN.md of the project as the canonical rule source, or `design-rules.md` when it is absent. The dimensions below are inspection prompts. They are not additional requirements.
- Cite the applicable source for a violation. Do not invent a threshold, ban, required component, or severity.
- Where the rules leave a choice open, report a measured usability concern as a recommendation. Do not report it as a compliance failure.

1. **Token/colour**: compare the actual colours, radii, and theme usage against the canonical tokens and permitted exceptions.
2. **i18n**: verify user-visible strings, accessible labels, shipped languages, and local punctuation and casing against the copy rules of the project.
3. **Component**: compare controls and composed patterns with the component registry, including documented migration allowances. Find the severity from the verified impact, not from the age of the component alone.
4. **Layout + action hierarchy**: measure spacing, padding, alignment, overflow, clipping, and action emphasis. Compare with the canonical layout and hierarchy rules.
5. **Elevation/motion**: inspect hover, active, focus, transitions, and reduced-motion behavior. Compare with the supported states and motion rules of the project. Do not impose a duration range or a transform ban that those rules do not have.
6. **A11y**: verify labels, semantics, focus, keyboard or platform interaction, contrast, target sizes, error association, and assistive-technology behavior against the applicable documented requirements. Take thresholds and exceptions from the canonical source. Distinguish measured failures from tests that could not run.
7. **State matrix**: inventory the applicable empty, loading, error, recovery, and responsive states. Verify their implementation against the state patterns of the project. Do not require a card, skeleton, or other pattern that the canonical rules do not require.
8. **Language + IA**: examine long and localized content, number readability, navigation, findability, and information order. Explain the observed task impact. Do not invent a maximum navigation depth.
9. **Consistency**: compare within-page patterns and 1-2 relevant sibling screens. Account for intentional documented variants. Name the pattern and the source in each verified mismatch.

## Scoring

- Prefer findings and coverage to a synthetic score.
  - If the user or project requires a score, use the rubric that the project defines. Label it a heuristic, not measured usability.
  - If no rubric exists, propose one before you present a numeric grade. Do not invent a 100-point result.
- Per-dimension status: ✅ clean · ⚠️ findings (P2/P3 only) · ❌ major (P0/P1 present) · unverified (required evidence unavailable) · not applicable (with reason).
- Track the required screens, branches, states, and measurements. If required coverage is not available, the verdict is _incomplete_. Assign no aggregate score.
- **Verdict:** use _no findings in verified design scope_, _needs fixes_, or _incomplete_.
  - A design review alone does not establish product release readiness, security or functional correctness.
  - A high score cannot override a known blocking defect.

## Output format

Use `reporting.md`. Give these items in this order:
1. Executive summary and priority counts.
2. Scope/environment and criteria.
3. Screen/state coverage linked to captures.
4. Numbered findings with screenshots.
5. Unverified tests and open items.
- Keep the per-dimension verification statuses from Scoring above.
- Technical P0-P3 references can accompany the user-facing priorities. Use the shared mapping.

No findings means clean only for a fully measured dimension. Mark unmeasured dimensions unverified. Never infer a perfect or ship-ready result from missing evidence.

## Multi-agent mode (`--multi`)

For a large or critical screen, a batch audit, or an explicit `--multi` request, use the agent orchestration of your tool. Without a trigger, run the same flow in series.

| Role | Model | Effort |
|---|---|---|
| Orchestration (deterministic script) | cheap | low |
| Discovery (branches/files/siblings) | small | low |
| Mechanical dimensions (hex/native/i18n/radius/states) | small | medium |
| Reasoning dimensions (IA/hierarchy/actions/consistency/a11y-APG) | large | high |
| Visual (screenshot) | large | high |
| Adversarial verification | at least as capable as strongest producer | supported effort appropriate to the risk |
| Code fix + score synthesis | large | high / medium |

Binding rules:
- The verifier is never cheaper than the producers. A weak verifier is a rubber stamp, and the whole score loses credibility.
- Mechanical dimensions use a small model but `medium` effort. Two-sided i18n and cascading CSS need multi-file context.
- Code fixes follow the branch and commit rules of the project.

## Sibling skills

| Skill | When |
|---|---|
| `real-plan` | Sharpen and gate a change before code |
| `real-audit` Product | Whole-product direction and next release |
| `real-audit` Module | Missing scenarios in a built module |
| `real-audit` Design | Screen or flow quality (this mode) |
| `real-audit` Performance | Measured web performance |
