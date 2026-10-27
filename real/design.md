# Design

Baseline rules live in `real-audit` `references/design-rules.md`. They are binding for UI work.
This file keeps only the extras.

## Precedence
- The project's own `DESIGN.md` wins. It sits on top of the baseline.
- Concrete tokens, colours and components go there.
- No third copy of the baseline. Change the canonical reference in this repo with a PR.
- Never put a second copy in an agent configuration folder.
<!-- Why: Copies drift apart and then contradict each other. -->

## Prototype delivery with all states
- Deliver design work as a prototype with all its states.
- Build every case: empty, loading, error, filled, first use, no permission, mobile, every role and every intermediate step.
- It must be a working, clickable prototype, not a gallery or single screens.
- It opens from the product's real entry page, for example its home page.
- Menu, sidebar, tab, dialog, row "..." menu, form and button work as in the app.
- No element may do nothing when clicked.
- Reach cases from inside the flow, not from a separate list.
- No "All screens" button. No yellow review notes.
- Build missing frame parts (search, notifications, language menu) from the app's own code and copy, never invented.
- Before delivery, click every clickable element on every screen, one by one, at 375 px and at desktop width.
<!-- Why: A gallery of static screens hides dead buttons and missing states. Reviewers want to click through a real flow. -->

## Order for interface work: measure mobile first
Use this when a screen, component or published page changes. Never skip it.
1. Render at 375 px and MEASURE. "Looks fine" in a screenshot is not a measurement.
2. Use numbers: `scrollWidth > clientWidth` (overflow), `documentElement.scrollWidth > innerWidth` (sideways scroll), touch target under 40 px, long text that does not wrap, truncated numbers.
3. Then desktop width, with the same measurements.
4. When both are clean, apply best practice: the `real-audit` design rules plus the project's `DESIGN.md`. The project file wins.
5. Fix in the source, not in the generated output. If a generator exists, fix it and regenerate.
<!-- Why: Layouts that look fine on desktop can break on a narrow screen. Numbers catch what eyes miss. -->
- A published interface change fires the "externally visible" trigger (trigger 1 in the README). A separate reviewer verifies the measurement.
- `real-audit` Design mode already asks for measured narrow-viewport checks. This adds the numbers and the fix-in-source rule.
- Open difference: `design-rules.md` says not to invent a universal touch-target threshold. The 40 px figure comes from the original rule. The user decides which governs.
