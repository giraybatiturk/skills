---
name: feature-gate
description: Runs BEFORE any code for a new feature. Discovers intent, measures what exists today, and puts scenarios plus five scope headings up for approval. No file is opened until the user approves.
disable-model-invocation: true
---

# /feature-gate

Argument: a feature or module name, or a one-line request (e.g. `media support for messaging`).

**No screen or endpoint file is opened for a new feature until this skill has run.** The five headings are shown to the user and approved first. If the user says "make it quick", the gate gets shorter; it does not get skipped.

## Why

Start coding directly and the frontend gets finished while the backend stays incomplete, the contract doesn't match, and the bug shows up in production. Measured case: in a messaging module, 10 of 21 scenarios were missing and the user found nearly all of them live. The unread badge never went down, only one of eight permission actions was implemented, the error text showed a raw backend code. None of that is visible on the happy path.

This skill's job is to produce that list **before the code is written**.

## Flow

### 0. Discover intent

Run `superpowers:brainstorming` if it's installed; otherwise ask the same questions yourself. Who is it for, which problem, what does success look like, what's out of scope. Even if the user says "it's obvious", ask at least three questions. Anything left vague becomes rework later.

### 1. Analysis: what exists today

**Measure, don't guess.** Apply the `/module-audit` inventory approach: existing endpoints, permission actions, error codes, screens, state coverage. Whatever you can't measure (backend contract, third-party behaviour), write **"could not measure"** in the report and name who verifies it.

Output: "today we have X, we don't have Y, Z is half done."

### 2. User stories

Every scenario in this shape:

```
As a <role> I want <action> so that <benefit>.

Accept   Given <precondition>, when <action>, then <expected result>.
```

The acceptance criterion must be **measurable**: not "works well" but "appears in the list and the counter goes up by 1".

Don't write only the happy path. At least one scenario for **each** of the eight classes:

1. **Permissions**: one scenario per backend-defined action; a user without it must not see the control
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
  - If a field is **added**, does the old client break? Adding a required field breaks; adding an optional one doesn't.
  - If a field is **missing**, what does the screen do? Every new optional field needs a written default behaviour.

  Precedent: an `approvalStatus` field defaulted to "approved" when absent, so the screen worked before the backend shipped. Written deliberately, so no incident. Left unwritten, every account would have shown "pending approval" until the field arrived.
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

Show the five headings. **No file is opened before approval.** Write down any scope changes that came with the approval, then start.

## Output

For a small feature, a table in chat is enough. For module-sized work, publish a shareable document (an Artifact); the team and the issue tracker get a link.

End with three separate lists:

- **Ours** (frontend): in order
- **Backend**: one list, goes to the issue tracker
- **Could not measure**: with who verifies each

## Sibling skills

| Skill | When |
|---|---|
| `/feature-gate` | Before writing code (this skill) |
| `/module-audit` | Missing scenarios in a built module |
| `/design-audit` | Screen is done; visual + DESIGN.md check |
| `/perf-audit` | Dependency added, before release |
| `/start` | When you don't know which one |
