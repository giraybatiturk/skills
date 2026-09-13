# Feature gate mode

Argument: a feature or module name, or a one-line request (e.g. `media support for messaging`).

Inspect the repository and running system read-only to establish what exists. Do not edit implementation files until the five headings are shown to the user and approved. If the user says "make it quick", the gate gets shorter; it does not get skipped.

## Flow

### 0. Discover intent

Use existing conversation and repository evidence first. Ask only the unresolved questions that materially change scope: who it is for, which problem, what success looks like, and what's out of scope. Do not make the user repeat facts already established. If a prerequisite changes the solution, ask 1–3 independent questions and defer dependent sections until answered. The five headings are required before implementation, not before this clarification.

### 1. Analysis: what exists today

**Measure, don't guess.** Apply the `real-audit` Module inventory approach: existing endpoints, permission actions, error codes, screens, state coverage. Whatever you can't measure (backend contract, third-party behaviour), write **"could not measure"** in the report and name who verifies it.

Output: "today we have X, we don't have Y, Z is half done."

### 2. User stories

Every scenario in this shape:

```
As a <role> I want <action> so that <benefit>.

Accept   Given <precondition>, when <action>, then <expected result>.
```

The acceptance criterion must be **measurable**: not "works well" but "appears in the list and the counter goes up by 1".

Don't write only the happy path. Assess these eight classes and write scenarios for applicable ones; mark others not applicable without inventing scope:

1. **Permissions**: one scenario per applicable backend-defined action; enforce authorization at the trusted boundary and specify whether unavailable controls are hidden or disabled
2. **State transitions**: set up / tear down / set up again; does the counter go down, does the cache refresh
3. **Error paths**: is there text for every error code; how many notifications does one error produce
4. **Empty and intermediate states**: no data / loading / error / unauthorised / waiting on a third party
5. **Multi-user**: two people open the same record; is "who did this" visible
6. **Third party**: what if the provider changes its format; how long does the token live; does our code match what the provider's own wizard generates
7. **Contract consistency**: same concept, same format and name everywhere; nullable consistent
8. **Environment and deployment**: anything that breaks for every customer on release; who provisions secrets

### 3. Backend scope

- Which endpoints: **existing or new**
- Which fields: type, nullable
- **Backwards compatibility, both directions:**
  - If a field is **added**, test old and new readers/writers against the actual schema. A newly required request field can break old callers; even optional response fields can break strict decoders. Do not infer compatibility from optionality alone.
  - If a field is **missing**, what does the screen do? Every new optional field needs a written default behaviour.

  Missing authorization or approval state must not silently grant access. Define an explicit unknown/unverified state unless the authoritative contract establishes a safe compatible default.
- **Permission actions**: which get seeded, which control each one unlocks
- **Error codes**: what the endpoint can return, does each go into the i18n dictionary
- Who does it, when

### 4. Frontend scope

- Screens and routes
- State matrix: empty / loading / error / unauthorised (the project's DESIGN.md state section)
- Copy: in every language the project ships, at the same time
- Variants: if the project is multi-brand or multi-vertical, does it differ per variant
- Mobile: what happens on a narrow screen
- Permissions: which action each control is tied to

### 5. Wiring

URL, body, headers, CORS, timeout, realtime channel, deployment constraint. Where the two sides meet.

### 6. Approval gate

Show the five headings. Read-only evidence gathering is permitted before approval; implementation edits require approval. Record approved scope changes, then start. Do not re-request approval already given for the same scope.

## Output

For a small feature, a table in chat is enough. For module-sized work, write a local report and link it in chat. External publication, team messages, or issue-tracker writes require explicit authorization for that action.

Keep ownership and missing evidence in the plan without repeating three closing lists in chat. Reuse existing implementation before proposing new components or infrastructure. Show the decision and the most important items first, link necessary detail when permitted, and name one next action if work remains. Do not shorten required analysis or tests just to shorten the response.

## Sibling skills

| Skill | When |
|---|---|
| `real-plan` discovery | Sharpen the idea before the gate |
| `real-plan` feature gate | Before writing code (this mode) |
| `real-audit` Module | Missing scenarios in a built module |
| `real-audit` Design | Screen is done; visual + DESIGN.md check |
| `real-audit` Performance | Measured web performance |
