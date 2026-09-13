# Design audit mode

Resolve the target from the user's selected scope and available screen/file/route context. For an explicitly focused visual request, the shared screenshot or preview route can identify the target without asking again. For an ambiguous audit request, use the entrypoint scope chooser; an open preview alone does not narrow an explicit full audit. Full scope starts with an inventory of all screens and applicable states.

Source of rules: the project's `DESIGN.md`. If there is none, `design-rules.md` is the baseline. **Never invent a rule.**

For animation, gesture, transition or feedback review, read `motion.md` in this directory. Motion belongs to UX/design; share runtime and interruption evidence with Performance and Quality without duplicating findings.

## Flow

0. Read `reporting.md` and use its screenshot evidence and coverage contract. **Start visual.** Spacing (box-to-box gaps, button padding, edge proximity), alignment, rhythm, colour and radius, states and consistency only show in the render; static code misses them. The user shares a preview screenshot, or headless capture runs if installed; **the user's live browser is not automated unless explicitly allowed right then.**
1. Read the screenshot + the target screen (component + its style file) + `DESIGN.md`. **For consistency**, scan 1-2 sibling screens too (same module, or same kind: list / detail / form).
1b. **Branch coverage: enumerate every branch and every collapsed, hidden or nested container.** Tabs, segment modes, conditional renders, **and containers hidden on open**: accordion panels, collapsibles, popover/dropdown/menu contents, modals/drawers, expandable rows, sub-sections. **Open each one and look inside**; audit separately. Each container gets a coverage entry: verified, unverified, or not applicable with a reason. Create a finding only for a verified defect; record missing screenshots or access as unverified coverage.
2. Audit **big picture → detail** (block frames before pixels):
   Order of attack: purpose and IA first, then layout and action priority, then the component cascade, then tokens, then the nine dimensions below one by one. Structure before pixels.
   If there's a structural problem higher up, **flag it first** instead of drowning in pixel/token detail. Every finding: `file:line`, dimension, priority (High/Medium/Low), critical-blocker flag when applicable, the applicable DESIGN.md or baseline section violated, one-sentence problem, concrete fix.
3. **Adversarially verify** every finding you're not sure of: actually read the line; kill false positives (is the hex in a comment, is it a `var(--*)`, is the translate an active state or a hover, is the native element a slot or a real control).
4. Report verified findings and coverage. Score only under the conditions below.
5. **Improve the code only with applicable user authorization.** Severity does not authorize edits. Otherwise report proposed fixes. For authorized fixes, run the project's appropriate checks and compare measured coverage and screenshots before/after.

## Dimensions

Use the project's DESIGN.md as the canonical rule source, or `design-rules.md` when absent. The dimensions below are inspection prompts, not additional requirements. Cite the applicable source for a violation; do not invent a threshold, ban, required component, or severity. Where the rules leave a choice open, report a measured usability concern as a recommendation rather than a compliance failure.

1. **Token/colour**: compare actual colours, radii, and theme usage against the canonical tokens and permitted exceptions.
2. **i18n**: check user-visible strings, accessible labels, shipped languages, and local punctuation/casing against the project's copy rules.
3. **Component**: compare controls and composed patterns with the component registry, including documented migration allowances. Determine severity from verified impact rather than component age alone.
4. **Layout + action hierarchy**: measure spacing, padding, alignment, overflow, clipping, and action emphasis. Compare with the canonical layout and hierarchy rules.
5. **Elevation/motion**: inspect hover, active, focus, transitions, and reduced-motion behavior against the project's supported states and motion rules. Do not impose a duration range or transform ban absent from those rules.
6. **A11y**: verify labels, semantics, focus, keyboard or platform interaction, contrast, target sizes, error association, and assistive-technology behavior against applicable documented requirements. Take thresholds and exceptions from the canonical source; distinguish measured failures from checks that could not run.
7. **State matrix**: inventory applicable empty, loading, error, recovery, and responsive states. Check their implementation against the project's state patterns; do not require a card, skeleton, or other pattern the canonical rules do not require.
8. **Language + IA**: examine long/localized content, number readability, navigation, findability, and information order. Explain observed task impact without inventing a maximum navigation depth.
9. **Consistency**: compare within-page patterns and 1-2 relevant sibling screens, accounting for intentional documented variants. Name the pattern and source involved in each verified mismatch.

## Scoring

- Prefer findings and coverage to a synthetic score. If the user or project requires a score, use the project's defined rubric and label it a heuristic, not measured usability. If no rubric exists, propose one before presenting a numeric grade; do not invent a 100-point result.
- Per-dimension status: ✅ clean · ⚠️ findings (P2/P3 only) · ❌ major (P0/P1 present) · unverified (required evidence unavailable) · not applicable (with reason).
- Track required screens, branches, states, and measurements. If required coverage is unavailable, verdict is _incomplete_ and no aggregate score is assigned.
- **Verdict:** use _no findings in verified design scope_, _needs fixes_, or _incomplete_. A design review alone does not establish product release readiness, security or functional correctness. A high score cannot override a known blocking defect.

## Output format

Use `reporting.md`: executive summary and priority counts, scope/environment and criteria, screen/state coverage linked to captures, numbered findings with screenshots and separate recommendations, then unverified checks and proposed next actions. Keep per-dimension verification statuses from Scoring above. Technical P0-P3 references may accompany the user-facing priorities using the shared mapping.

No findings means clean only for a fully measured dimension. Mark unmeasured dimensions unverified; never infer a perfect or ship-ready result from missing evidence.

## Multi-agent mode (`--multi`)

For a large or critical screen, a batch audit, or an explicit `--multi` request, use the current client's agent orchestration. Without a trigger, run the same flow serially.

| Role | Model | Effort |
|---|---|---|
| Orchestration (deterministic script) | cheap | low |
| Discovery (branches/files/siblings) | small | low |
| Mechanical dimensions (hex/native/i18n/radius/states) | small | medium |
| Reasoning dimensions (IA/hierarchy/actions/consistency/a11y-APG) | large | high |
| Visual (screenshot) | large | high |
| Adversarial verification | at least as capable as strongest producer | supported effort appropriate to the risk |
| Code fix + score synthesis | large | high / medium |

Binding: the verifier is never cheaper than the producers; a weak verifier is a rubber stamp and the whole score loses credibility. Mechanical dimensions use a small model but `medium` effort (two-sided i18n and cascading CSS need multi-file context). Code fixes follow the project's branch/commit rules.

## Sibling skills

| Skill | When |
|---|---|
| `real-plan` | Sharpen and gate a change before code |
| `real-audit` Product | Whole-product direction and next release |
| `real-audit` Module | Missing scenarios in a built module |
| `real-audit` Design | Screen or flow quality (this mode) |
| `real-audit` Performance | Measured web performance |
