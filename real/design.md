# Design

The baseline rules live in one place: `real-audit` `references/design-rules.md`, in this repo. `real-plan` and `real-audit` load it for UI and interface work; its rules are binding. This file keeps only the deltas.

## Precedence and copies
- The project's own `DESIGN.md` wins when it exists; it sits on top of the baseline. Concrete tokens, colours and components are written there.
- No third copy. If the baseline must change, change the canonical reference in this repo with a PR. Never put a second copy in an agent configuration folder.

## Prototype delivery with all states
- Design work is delivered as a prototype with all its states. Whatever is being built (screen, feature, flow), produce every case: empty, loading, error, filled, first use, no permission, mobile, every role and every intermediate step.
- The deliverable is a working, clickable prototype, not a gallery or a set of single screens. It opens from the product's real entry page (for example its home page). Menu, sidebar, tab, dialog, row "..." menu, form and button work as in the app; no element is left that does nothing when clicked.
- Cases are reached from inside the flow, not shown as a separate list. The prototype has no "All screens" button and no yellow review notes.
- Frame parts missing from the mockup (search, notifications, language menu and so on) are built from the app's own code and copy, never invented.
- Before delivery, click every clickable element on every screen, one by one, at 375 px and at desktop width.

## Order for interface work: measure mobile first, then best practice
When a screen, component or published page changes, this order is not skipped:
1. Render at 375 px and MEASURE. Looking at a screenshot and saying "looks fine" is not a measurement. Use numbers: `scrollWidth > clientWidth` (overflow), `documentElement.scrollWidth > innerWidth` (sideways scroll), touch target under 40 px, long text that does not wrap, truncated numbers.
2. Then desktop width, with the same measurements.
3. When both are clean, apply best practice: the `real-audit` design rules plus the project's own `DESIGN.md`. The project file wins.
4. Fix in the source, not in the generated output. If a generator exists (script, template), fix it and regenerate.
- A published interface change already fires the "externally visible" orchestration trigger (trigger 1 in the README; see `models-and-orchestration.md`); a separate reviewer verifies the measurement.
- `real-audit` Design mode already asks for measured narrow-viewport checks; this order keeps the same idea with the specific numbers and the fix-in-source rule.
- Difference, not resolved here: `design-rules.md` says not to invent a universal touch-target threshold, while the 40 px figure above comes from the original rule. The user decides which governs.
