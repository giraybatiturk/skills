# Feature gate mode

Argument: a feature or module name, or a one-line request (for example `media support for messaging`).

Inspect the repo and the running system read-only to find what exists.
- Do not edit implementation files until the user has seen and approved the five headings.
- If the user says "make it quick", make the gate shorter. Do not skip it.

## Flow

### 0. Discover intent

Use the existing conversation and repo evidence first.
- Ask only the unresolved questions that change the scope materially.
- These questions are: who it is for, which problem, what success looks like, and what is out of scope.
- The answer to "what success looks like" ends with at least a primary metric. Or it ends with **Could not measure** and a named verifier.
- Do not make the user repeat facts that you already established.
- If a prerequisite changes the solution, ask 1–3 independent questions. Defer the dependent sections until the user answers.
- The five headings are required before implementation. They are not required before this clarification.

### 1. Analysis: what exists today

**Measure, don't guess.** Apply the `real-audit` Module inventory approach: existing endpoints, permission actions, error codes, screens, state coverage.
- Write **"could not measure"** in the report for whatever you cannot measure (backend contract, third-party behaviour). Name who verifies it.

Output: "today we have X, we don't have Y, Z is half done."

### 2. User stories

Write every scenario in this shape:

```
As a <role> I want <action> so that <benefit>.

Accept   Given <precondition>, when <action>, then <expected result>.
```

The acceptance criterion must be **measurable**. Do not write "works well". Write "appears in the list and the counter goes up by 1".

Do not write only the happy path. Assess these eight classes. Write scenarios for the classes that apply. Mark the others not applicable. Do not invent scope.

1. **Permissions**: one scenario for each applicable backend-defined action. Enforce authorization at the trusted boundary. Specify if unavailable controls are hidden or disabled
2. **State transitions**: set up / tear down / set up again; does the counter go down, does the cache refresh
3. **Error paths**: is there text for every error code; how many notifications does one error produce
4. **Empty and intermediate states**: no data / loading / error / unauthorised / waiting on a third party
5. **Multi-user**: two people open the same record; is "who did this" visible
6. **Third party**: what if the provider changes its format; how long does the token live; does our code match what the provider's own wizard generates
7. **Contract consistency**: same concept, same format and name everywhere; nullable consistent
8. **Environment and deployment**: anything that breaks for every customer on release; who provisions secrets

#### Measure block

Add it only when the plan states an outcome goal, for example "raise signup conversion". Put it at the end of the User story heading. The five headings stay the same.

Fields:
1. Primary metric and its formula: numerator and denominator.
2. Event and property names.
3. Data source.
4. Baseline: a value, or "read it on the measure date", with its window.
5. Target, labelled "requirement" or "proposal".
6. Guardrails with their limits. Use at most two.
7. Minimum sample, or "default".
8. Wait window and the planned measure date.
9. Release marker: date and time, version or flag.
10. Data owner.

Rules:
- Use the metric-tree rule of `real-audit` Product mode. Put each metric in one class: measurable now, requires instrumentation, requires qualitative research, or unsuitable.
- Put each missing event in Backend scope with its name, properties, trigger and owner.
- Advice line: if the release uses a flag, plan a holdout or a flag-based split. Then `real-measure` can compare both groups in the same period. This is not required.
- `real-measure` reads this block after release. A before and after result says "associated with".

### 3. Backend scope

- Which endpoints: **existing or new**
- Which fields: type, nullable
- **Backwards compatibility, both directions:**
  - If a field is **added**, test old and new readers and writers against the actual schema.
    - A newly required request field can break old callers.
    - Even optional response fields can break strict decoders.
    - Do not infer compatibility from optionality alone.
  - If a field is **missing**, what does the screen do? Write a default behaviour for every new optional field.

  A missing authorization or approval state must not grant access silently. Define an explicit unknown or unverified state. Do this unless the authoritative contract establishes a safe compatible default.
- **Permission actions**: which get seeded, which control each one unlocks
- **Error codes**: what the endpoint can return, does each go into the i18n dictionary
- Who does it, when

### 4. Frontend scope

- Screens and routes
- State matrix: empty / loading / error / unauthorised (the state section of the DESIGN.md of the project)
- Copy: in every language that the project ships, at the same time
- Variants: if the project is multi-brand or multi-vertical, does it differ for each variant
- Mobile: what happens on a narrow screen
- Permissions: which action each control is tied to

### 5. Wiring

URL, body, headers, CORS, timeout, realtime channel, deployment constraint. This is where the two sides meet.

### 6. Approval gate

Show the five headings.
- You can gather read-only evidence before approval. Implementation edits need approval.
- Record approved scope changes. Then start.
- Do not ask again for approval that the user already gave for the same scope.

## Output

For a small feature, a table in chat is enough. For module-sized work, write a local report and link it in chat. External publication, team messages and issue-tracker writes need explicit authorization for that action.

Keep ownership and missing evidence in the plan. Do not repeat three closing lists in chat.
- Reuse existing implementation before you propose new components or infrastructure.
- Show the decision and the most important items first. Link necessary detail when permitted. If work remains, name one next action.
- Do not shorten the required analysis or tests only to shorten the response.

## Sibling skills

| Skill | When |
|---|---|
| `real-plan` discovery | Sharpen the idea before the gate |
| `real-plan` feature gate | Before writing code (this mode) |
| `real-audit` Module | Missing scenarios in a built module |
| `real-audit` Design | Screen is done; visual + DESIGN.md check |
| `real-audit` Performance | Measured web performance |
