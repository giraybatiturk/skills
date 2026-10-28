# Design

The baseline rules are in `real-audit` `references/design-rules.md`. They are binding for UI work.
This file has only the extra rules.

## Precedence
- The `DESIGN.md` of the project wins. It sits on top of the baseline.
- Write concrete tokens, colours and components in that file.
- Do not make a third copy of the baseline. Change the canonical reference in this repo with a PR.
- Do not put a second copy in the configuration folder of an agent.
<!-- Why: Copies drift apart and then contradict each other. -->

## Prototype delivery with all states
- Deliver design work as a prototype with all its states.
- Build every case: empty, loading, error, filled, first use, no permission, mobile, every role and every intermediate step.
- Make a working, clickable prototype. Do not make a gallery or single screens.
- Start the prototype from the real entry page of the product, for example its home page.
- Make the menu, sidebar, tab, dialog, row "..." menu, form and button work as in the app.
- Do not leave an element that does nothing when the user clicks it.
- Reach each case from inside the flow, not from a separate list.
- Do not add an "All screens" button. Do not add yellow review notes.
- Build missing frame parts (search, notifications, language menu) from the code and copy of the app. Never invented.
- Before delivery, click every clickable element on every screen, one by one, at 375 px and at desktop width.
<!-- Why: A gallery of static screens hides dead buttons and missing states. -->

## Order for interface work: measure mobile first
Do these steps when a screen, component or published page changes. Do not skip a step.
1. Render at 375 px and MEASURE. "Looks fine" in a screenshot is not a measurement.
2. Use numbers: `scrollWidth > clientWidth` (overflow), `documentElement.scrollWidth > innerWidth` (sideways scroll).
3. Also measure: touch target under 40 px, long text that does not wrap, truncated numbers.
4. Then desktop width, with the same measurements.
5. When both are clean, apply best practice: the `real-audit` design rules and the `DESIGN.md` of the project. The project file wins.
6. Fix in the source, not in the generated output. If a generator exists, fix it and regenerate.
<!-- Why: A layout that looks right on desktop can break on a narrow screen. -->
- A published interface change is an externally visible change. It starts orchestration. A separate reviewer verifies the measurement.
- `real-audit` Design mode already asks for measured narrow-viewport tests. This file adds the numbers and the fix-in-source rule.
- Open difference: `design-rules.md` says not to invent a universal touch-target threshold. The 40 px figure comes from the original rule. The user decides which rule governs.

## Screenshot and remark loop
Use this loop when the user sends a screenshot with a short remark about the interface.
1. Read the image and the remark. Say the change in one line.
2. Make the smallest change that answers the remark. Fix it in the source.
3. Capture "before" once for the task, at 375 px and at 1280 px.
4. Capture "after" at both widths after each change.
5. Measure both widths with the order above. Report the numbers: sideways scroll, targets under 40 px, long text that does not wrap.
6. Show before and after side by side on one page with a white background. Give the link.
7. Use the `real-shot` mode of `real-test` for steps 3 to 6. It writes the images, the numbers and the comparison page.
8. Do not write "looks fine" without numbers.
9. If the remark is ambiguous, make the most likely change and show it. Do not ask first.
<!-- Why: Most interface feedback is a screenshot with a short remark. Without a before and after and without numbers, each remark needed many rounds. -->
