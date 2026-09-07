---
name: design-audit
description: Audits one screen against the project's DESIGN.md from a screenshot plus the code, scores it across 9 dimensions, and fixes on approval. Runs when a screen is done.
disable-model-invocation: true
---

# /design-audit

Argument: a screen or file path or name (e.g. `VoucherEntryScreen`). **If missing, audit the screen open in the preview**: resolve the route from the screenshot or URL the user shared and proceed without asking. If neither exists, ask which screen.

Source of rules: the project's `DESIGN.md`. If there is none, the `design-rules` skill is the baseline. **Never invent a rule.**

## Flow

0. **Start visual.** Spacing (box-to-box gaps, button padding, edge proximity), alignment, rhythm, colour and radius, states and consistency only show in the render; static code misses them. The user shares a preview screenshot, or headless capture runs if installed; **the user's live browser is not automated unless explicitly allowed right then.**
1. Read the screenshot + the target screen (component + its style file) + `DESIGN.md`. **For consistency**, scan 1-2 sibling screens too (same module, or same kind: list / detail / form).
1b. **Branch coverage: enumerate every branch and every collapsed, hidden or nested container.** Tabs, segment modes, conditional renders, **and containers hidden on open**: accordion panels, collapsibles, popover/dropdown/menu contents, modals/drawers, expandable rows, sub-sections. **Open each one and look inside**; audit separately. Each hidden container gets its own finding; ask for a screenshot of each where possible.
2. Audit **big picture → detail** (block frames before pixels):
   1) Purpose + IA / content order and priority → 2) Layout, hierarchy, action priority → 3) Component/cascade → 4) Token/colour/radius → 5) Typography/language → 6) State matrix + branch coverage → 7) A11y → 8) Interaction → 9) Consistency (internal + external).
   If there's a structural problem higher up, **flag it first** instead of drowning in pixel/token detail. Every finding: `file:line`, dimension, severity (P0/P1/P2/P3), the DESIGN.md section violated, one-sentence problem, concrete fix.
3. **Adversarially verify** every finding you're not sure of: actually read the line; kill false positives (is the hex in a comment, is it a `var(--*)`, is the translate an active state or a hover, is the native element a slot or a real control).
4. Score and report.
5. **Improve the code.** On approval (directly for clear P0/P1), apply the findings; verify with the project's typecheck + lint; score again (before → after). Compare screenshots before/after where possible.

## Dimensions

Each dimension's rule comes from the relevant DESIGN.md section; the list below says **where to look**, not what the rule is.

1. **Token/colour**: hard-coded brand hex / fixed radius, retired tokens, brand values outside the theme file.
2. **i18n**: hard-coded strings (JSX/placeholder/aria-label/alt), drift between languages, smart quotes (U+2019), em dashes (U+2014).
3. **Component**: native `<input>/<button>/<select>/<textarea>` or raw inline `<svg>` outside the project's component cascade; one-off custom components inside a screen.
   - **Canon parity:** if DESIGN.md has a canonical component registry, compare every component on the screen with it. Legacy usage = P1, name the canon it deviates from. A duplicate pattern not in the registry (two components doing the same job) = P2 process finding.
4. **Layout + spacing + action hierarchy**:
   - **Equal** box-to-box gaps (inside a group < between groups); off-scale px; button padding symmetric + horizontal > vertical + same kind same padding; fixed edge inset, nothing glued to an edge; invisible-grid alignment; consistent vertical rhythm. **Mostly measured from the screenshot.**
   - **Button priority:** one primary per view; secondary muted, destructive soft; two primaries side by side = finding.
5. **Elevation/motion**: `transform/translate/scale` on hover (except active `translate-y-px`); transition durations outside 120-200 ms.
6. **A11y** (WCAG 2.2 AA + WAI-ARIA APG): contrast text ≥ 4.5:1, large text/UI ≥ 3:1, light + dark; every interaction by keyboard, sensible Tab order, `focus-visible` not overridden; complex widgets with APG role + arrow keys; errors via `aria-invalid` + `aria-describedby`; every input has a visible label; icon buttons have `aria-label`; decorative icons `aria-hidden`; meaning never carried by icon/colour alone; touch targets ≥ 44 px; `prefers-reduced-motion`; heading order doesn't skip.
7. **State matrix**: empty / loading (skeleton) / error defined; mobile card on list/table screens.
8. **Language + IA**: local glyphs/casing, agglutination overflow/truncation, tabular numerals; navigation depth ≤ 3, findability, consistent action placement. **Content order:** is every field in logical order + priority (input → derived, related info in one block, one entity not split). Wrong order = correctness + trust finding.
9. **Consistency**, two axes:
   - **Internal (within the page):** same element looks/behaves the same: spacing rhythm, button style/size, heading scale, icon set, section layout.
   - **External (across screens):** same pattern as sibling screens: header strip, action placement, section structure, terminology, tokens, **same component for the same pattern**. Name the sibling screen it deviates from.

## Scoring

- Start at **100**. Every verified finding deducts: **P0 −20 · P1 −10 · P2 −4 · P3 −1**. Floor 0.
- Per-dimension status: ✅ clean · ⚠️ minor (P3 only) · ❌ major (P0/P1 present).
- **Verdict:** _ship-ready_ = score ≥ 90 AND no P0/P1. Otherwise _needs fixes_.

## Output format

```
Design compliance: <screen> - <score>/100 (<verdict>)

Dimension scores:
  Token/colour      ✅ / ⚠️ / ❌
  i18n              ...
  Component         ...
  Layout            ...
  Elevation/motion  ...
  A11y              ...
  State matrix      ...
  Language + IA     ...
  Consistency       ...  (internal + external; name the sibling screen)

Findings (by severity, worst first):
  [P1] file:line - <problem> → <fix>  (DESIGN.md <section>)
  [P2] ...
```

Apply only DESIGN.md rules. No findings means the dimension is ✅ and the score is 100.

## Multi-agent mode (`--multi`)

For a large or critical screen, or a batch audit: `/design-audit <screen> --multi` fans out through a Workflow. Without the flag it's a single agent running the same flow serially.

| Role | Model | Effort |
|---|---|---|
| Orchestration (deterministic script) | cheap | low |
| Discovery (branches/files/siblings) | small | low |
| Mechanical dimensions (hex/native/i18n/radius/states) | small | medium |
| Reasoning dimensions (IA/hierarchy/actions/consistency/a11y-APG) | large | high |
| Visual (screenshot) | large | high |
| Adversarial verification | large | **one notch above the producers** |
| Code fix + score synthesis | large | high / medium |

Binding: the verifier is never cheaper than the producers; a weak verifier is a rubber stamp and the whole score loses credibility. Mechanical dimensions use a small model but `medium` effort (two-sided i18n and cascading CSS need multi-file context). Code fixes follow the project's branch/commit rules.

## Sibling skills

| Skill | When |
|---|---|
| `/feature-gate` | Before writing code |
| `/module-audit` | Missing scenarios in a built module |
| `/design-audit` | Screen is done (this skill) |
| `/perf-audit` | Dependency added, before release |
| `/start` | When you don't know which one |
