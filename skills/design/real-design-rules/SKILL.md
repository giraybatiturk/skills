---
name: real-design-rules
description: Binding baseline rules for any UI work (token discipline, forms, states, accessibility, UX writing). Load for any screen, component, form or visual task. The project's own DESIGN.md takes precedence.
---

# Design rules (baseline)

These rules bind whenever you do UI work in any project. They are project-agnostic. If the project has its own `DESIGN.md`, **that wins**; this file is the floor.

## 0. Principles

- **Less, and clear.** One main job per screen; everything else recedes.
- **Consistency over creativity.** The same thing looks and behaves the same everywhere.
- **Stay tied to the real source.** Don't invent components, sizes or colours; pull them from the design system, the registry, the docs. If you don't know, don't guess, ask.
- **Accessibility is not optional.** Keyboard, contrast and screen readers are considered from the start.

## 1. Design system and token discipline

- UI is built from **the design system's components** (shadcn/Base UI, MUI, whatever the project has). No hand-rolled button/input/dialog/card markup.
- Need a variation? Solve it with the component's **existing prop / variant / size** first.
- Colour, spacing, radius, shadow and typography come from **semantic tokens** (`bg-primary`, `text-muted-foreground`, `rounded-md`, `gap-4`). No raw hex/px; never step outside the tokens.
- Layout (grid/flex/spacing) is utility classes; visual parts (card, field, button, badge, menu) are always components.

## 2. New component protocol (warn first)

If something the system doesn't have is needed, **don't write it; stop and say so.**
1. **Flag it:** say "the system doesn't have this" before burying it in a screen.
2. **Search the source:** registry / docs; if it exists, pull it from the real source.
3. **Compose:** can existing primitives be combined (Popover + Command, Field + Input)?
4. **Decide together:** if still needed, agree to add it as a permanent component. No one-off, in-screen custom components.

## 3. Visual hierarchy and layout

- **What should be seen first?** The main action/information is strongest; secondary things are weak. If everything stands out, nothing does.
- Build hierarchy with **size, weight, contrast and space**, not colour.
- Group related items by **proximity**; separate different things with space. Try space before adding lines or boxes.
- Visual simplicity: no unnecessary frames, shadows, dividers or decoration. Every element earns its place.

## 4. Typography

- A limited **scale** (e.g. 12/14/16/20/24); no in-between values.
- Hierarchy: size + weight. Comfortable line height for body (~1.5), tight for headings.
- Readable measure (~60-75 characters). Not everything bold; emphasis is rare.

## 5. Colour and contrast

- Palette from tokens; neutrals carry the body, **primary** is for action, **accent** for emphasis. Brand colour is identity, not every button.
- Text/background contrast **WCAG AA** (4.5:1 body, 3:1 large).
- **Never carry meaning by colour alone.** Status/error gets an icon + text as well.
- Light and dark both work; tokens hold AA in both themes.

## 6. Spacing and size

- One consistent **spacing scale** (4/8 px grid); no arbitrary px.
- Let content breathe; rhythm over crowding. Equal, predictable gaps.
- Touch targets at least ~40 px; clickable areas big enough.

## 7. Forms

### Label
- Every field has a **visible label**; a placeholder is not a label.
- Short noun phrase, sentence case: "Email address", "Phone number".
- Required marker consistent (`*` or "(required)"), the same on every form.

### Placeholder
- **Use sparingly**, only for a format example: `name@example.com`, `5XX XXX XX XX`.
- No instructions or required information (it disappears on focus, isn't accessible). No example, no placeholder.

### Help text
- **Below** the field, static, short (~20 words). Explains the expected format or reason.

### Validation
- **Inline** and **on blur** (or while typing); never only a batch of errors on submit.
- Error pattern: `[Field] [specific requirement]`: "Email needs an @", "Password needs at least 8 characters", "Pick a future date".
- No blaming language ("invalid", "wrong"). Solution-oriented, specific.
- Error is **icon + text**, below the field; never colour alone.

### Composition and actions
- Fields are built from the system's form primitives (Field + Label + control + Description + Error). Don't write your own label/error markup.
- Invalid/focus/disabled looks come from state props (`data-invalid`/`aria-invalid`); no hand-set colours/borders.
- Primary action is a clear button; secondary/cancel is muted (ghost/outline).
- Button copy is verb + object: "Save", "Delete account". No generic "Submit", "OK".
- Loading uses the button's `loading`/disabled state; no separate spinner.

### Accessibility
- Label ↔ input bound; error bound with `aria-describedby`.
- Whole form navigable by keyboard; `focus-visible` ring preserved.

## 8. Icons

- **One icon set** (usually `lucide-react`); don't mix libraries.
- The component sets icon size; no manual `size-*` (except a lone icon outside a component).
- Decorative icon `aria-hidden`; clickable icon has a visible label or `aria-label`. Never carry meaning by icon alone.

## 9. States and feedback

- **Empty state:** short title + one action that says what to do. Don't leave "No data"; give a way out.
- **Loading:** a **skeleton** that mimics the layout (not an empty screen or a lone centred spinner); a spinner only for short inline waits.
- **Error:** field errors inline; section/page errors get a title + "Try again", non-blaming language.
- **Toast:** short, transient result of an action ("Saved", "Link copied"). Persistent or long information goes inline, not in a toast.

## 10. Copy (UX writing)

- Purposeful, short, conversational, clear. Short sentences (8-14 words).
- Write in the user's language, not the system's. Avoid jargon and technical terms.
- **No em dashes.** Plain punctuation: comma, full stop, parentheses.

## 11. Process

- Design/UI audits go through **`/real-design-audit`** (it orchestrates the installed skills: critique loop, refactoring UI, component registry, UX writing, visual verification).
- Before saying "done": does it speak the target design system's language, did anything step outside the tokens, are the form/state/accessibility rules met?

## 12. Out of scope

- **Brand colour choice** isn't here; it's defined in the project's tokens.
- No particular aesthetic (brutalist/minimal/glass) is imposed; follow the project's direction. This file is about **applying that direction well**.
