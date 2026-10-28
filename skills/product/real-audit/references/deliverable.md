# Deliverable audit mode

Critique a finished visual deliverable the way a designer reads it: catalogue, deck, poster, page template, artboard, exported PDF.
- The evidence is the render, not the source.
- Do not cite class names, variables, file paths or data files here.
- If the render shows data, logic, truncation or fabricated values, mark it in one line for Design or Module mode. Do not open it in this report.

Use this mode when the artefact is a produced visual output. Use `design.md` when an interface exists in code and `file:line` evidence is available and useful.
- If a template or script in the same project generates a deliverable, audit the render here. Route implementation defects to Design.
- Keep the two reports separate. Neither report duplicates the findings of the other.

## 1. Establish target and authority

- Identify what is under audit: canvas artboards, PDF, deck, HTML page, exported image. If the user already stated it, do not ask again.
- Use this order for the source of rules:
  1. The `DESIGN.md` or design-system README of the project.
  2. The recorded decisions in the project context.
  3. General design principles.
- **Never invent a rule.** Do not write a threshold, ban or required component that the source does not have. Where the source is silent, label the observation a judgment.
- Establish the reader and the reading situation: two minutes on a phone, searching at a desk, three seconds on a wall. Use the context if it is available. If not, ask one time.

## 2. Scope

Honor the scope that the user already gave. If not, ask one choice question with these options:
- **Focused** (one page type)
- **Key pages** (the two or three most repeated and most seen page types; recommended)
- **Full** (every page type)

- For repeating pages, one example for each type is enough.
- When density varies materially, add the fullest and the emptiest example.

## 3. Evidence: render first

- Make no finding without a render. If the user did not share one, produce it locally when possible (canvas files, HTML, PDF pages).
- If you cannot produce a render, that page is **unverified**. Do not speculate.
- Inspect at true size: page dimensions and typical viewing distance for print, target device width for screen.
- Reuse one capture for several findings on the same page. Never redraw or regenerate a capture as evidence.

## 4. Order of attack: structure before detail

Read each page type in this order. If there is a structural problem higher up, record it before you go down to detail.

1. **Purpose and reading order.** Does the page do one job? Where does the eye start, where does it go, where does it stall?
2. **Hierarchy.** Does the order that size, weight, colour and space build match the real order of importance? Look for different things that look equal, and equal things that look different.
3. **Rhythm and space.** Do block gaps sit on a scale? Is the balance of filled and empty deliberate or residual? Are margins and header/footer positions consistent across page types?
4. **Typographic application.** Are scale steps used in the right place? Are line length and leading readable? Do uppercase labels and weight contrasts create noise? Check broken headings and single-word lines.
5. **Colour and emphasis.** How many places carry the accent, and what does it mark? If everything is emphasis, nothing is. Judge contrast against the thresholds that the source documents. Do not call it low without measuring.
6. **Component consistency.** Do elements that do the same job look the same (label bands, numbered steps, chips, footnotes)? Compare with sibling pages.
7. **Medium legibility.** Print: point size, hairline rules, grey text, how gradient bands reproduce, behaviour in black and white. Screen: what disappears in a reduced preview.

## 5. Writing rules

- Write at most three observations for each heading. Keep the whole report within two screens.
- Every observation carries four items:
  - which page
  - where in the render (top left, masthead band, second column)
  - what is visible
  - the effect on the reader
- Label each one:
  - **[Observation]** measurable or plainly present in the render
  - **[Judgment]** a design call that is open to debate
  - **[Rule]** contrary to `DESIGN.md` or a recorded decision, with the source named
- **Describe the defect and its mechanism; do not design the correction.**
  - A finding: "The masthead band sits closer to the title than the section gap elsewhere on the page, so the two read as one block".
  - A remedy: "Match that gap to the section spacing". It belongs to the reader.
  - Where useful, state the observable outcome that would show the finding resolved.
- Do not give scores or percentages. Use the shared High / Medium / Low priorities from `reporting.md`.
  - High breaks reading or defeats the purpose of the page.
  - Medium is friction.
  - Low is polish.
- Do not use technical language: class names, variables, file paths and patterns are out of scope here. Token names are acceptable for colour (terracotta, muted-dark) because they are design vocabulary.
- When the work under review is the work of the user, do not condescend. State the position plainly and give the reasoning.
- Follow the language and typography conventions of the project for the report itself.

## 6. Report format

Use `reporting.md` for priorities, evidence handling and coverage. Keep the shape of this mode:

1. **Verdict** (two sentences): whether the page does its job, and the single largest problem.
2. **Findings** grouped under High / Medium / Low, each naming its capture.
3. **Unverified**: pages that you could not render or properties that you could not measure (contrast, a print proof), and who can verify them.
4. **Hand off to Design or Module**: data and logic problems as a one-line list.
5. One concrete next step.
