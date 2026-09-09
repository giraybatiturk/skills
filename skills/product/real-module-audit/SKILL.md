---
name: real-module-audit
description: Audits a built feature or module against user scenarios. Finds the missing cases by MEASURING the code and the backend contract; produces scenarios in eight classes, a permission matrix, and a priority order.
disable-model-invocation: true
---

# /real-module-audit

Argument: module or feature name (e.g. `messaging`, `appointments`, `payments`). If missing, ask which module is being worked on.

**When to run**

- Touching a module for the **second time** (adding on top, not building from scratch)
- When the "why doesn't this work" rounds start: once one bug is found, ask **what else in the same class is broken**
- **Before going live**: the module works in test, hasn't reached a customer yet
- Coming back to a module nobody touched for a while

Two modes:

- **Up front** (new feature, before code): produces the `/real-feature-gate` five headings for approval.
- **After the fact** (built, running module): inventories scenarios from the code and marks the gaps.

## Why

Start coding directly and the **happy path** gets done; error paths, permission states and state transitions stay missing. The user finds them one by one in production, and each one becomes its own round.

Measured case (a messaging module): 10 of 21 scenarios were missing, 5 were half done. The user found most of them. The unread badge never went down, the counter stayed full after a disconnect, the error text showed a raw backend code, only one of eight permission actions was implemented. None of it is visible on the happy path; all of it shows on the second step.

## Flow

0. **Measure, don't guess.** Run the inventories. Whatever you can't measure (backend contract, third-party behaviour), write **"could not measure"** in the report and name who verifies. Never assume silently.
1. Produce the inventories (endpoints, permissions, error codes, states).
2. Apply every class in the checklist to the module; write a scenario for each.
3. Write each scenario as **role + action + acceptance criterion**, then **what happens today** and **owner** (frontend / backend / devops).
4. Mark status: `working` (tried end to end) · `half` (one side ready, the other missing) · `missing`.
5. Report; propose an order (release gates on top).
6. On approval, fix the frontend gaps; send the backend gaps to the issue tracker as one list.

## Inventories

Derive the commands for the project yourself; on the first run, record the paths you found in the project's `AGENTS.md`/`CLAUDE.md` so the next run doesn't grep. Seven questions need answers:

```bash
# 1. Endpoints: every URL the module talks to
grep -rnoE "['\"](/?api/)?v[0-9]+/<module>[a-zA-Z/_-]*['\"]" <api-client-dir> | sort -u

# 2. Permission actions: what the backend DEFINED
# If not in a contract file, read the admin panel's permission matrix and write a regression test.
grep -rn "<MODULE>_\(MODULE\|ACTION\)\|can(['\"]<module>" <types-dir>

# 3. Which actions the frontend ASKS for: the gap vs (2) is the most common miss
# Scan screen + route + app root (route gate) together; skip one and
# "gate exists but no check inside the screen" stays invisible.
grep -rn "can(" <screens-dir>/<module> <routes-dir> <App-file> | grep -i <module>

# 4. Error code coverage: are the module's codes in the dictionary
grep -n "<MODULE>_" <i18n-dictionary>

# 5. How many places show an error: double-notification hunt
grep -rn "toast.*error\|onError" <screens-dir>/<module>

# 6. Raw error text leak (repo-wide class bug)
grep -rn "error(\(err\|error\)\.message" <src-dir> | wc -l

# 7. State matrix coverage
grep -c "Skeleton\|Empty\|isError\|retry" <screens-dir>/<module>/*.tsx
```

## Checklist, class by class

At least one scenario per class. Skipping a class leaves that class's bug for production.

### 1. Permissions

- A separate scenario for **every action** the backend defines: a user without it must **not see** the control.
- Asking only for the module gate isn't enough; `send`, `delete`, `add` must be asked for separately INSIDE the screen.
- Test question: "what happens if someone without the permission presses this button?" If the answer is "backend returns 403", the button should never have rendered.

### 2. State transitions (not just the initial state)

- Set up → tear down → set up again. At each step, what does **the rest of the panel** show?
- Counters and badges: do they go up, do they **go down**, do they reset? A counter that only increments is a bug.
- Sign out/in, switch account or company, change permission: is the cache holding stale data?
- Do the mutations invalidate the queries that depend on them? Delete a record and every place that counts it must refresh.

### 3. Error paths

- For **every error code** the backend can return: is there a dictionary entry, or does the raw code hit the screen?
- How many notifications does one error produce? Global handler + the screen's own = two.
- Raw `err.message` is never shown: the backend `message` field usually carries a **code**, not user text.
- Network down, timeout, server 500: which text appears?

### 4. Empty and intermediate states

- No data · loading · error · unauthorised · waiting for third-party approval · third party rejected.
- **How many empty-state messages** show at once on the same screen? More than one and the user has to pick which to read.

### 5. Multiple users and many records

- Two users open/edit the same record at the same time?
- Is "who did this" visible? In a multi-person account, "who wrote this reply" needs an answer.
- With thousands of records, is search enough, or do you need filters and totals?

### 6. Third-party dependency (if any)

- Is there an approval/review state on the provider side, and can the user see it?
- What if the provider changes its data format? A renamed field can silently drop data.
- How long does the token we store live, does it refresh, how does the user notice when it breaks?
- Does the connection survive a server restart?

**Setup verification: compare against the provider's own output.** Most providers have a wizard in their console that generates code "for your app" (Meta's Embedded Signup Builder, Stripe's integration samples). Compare our code **line by line** with what it generates: version fields the same (flow, SDK and API versions can differ), any required parameter missing, every item in the console checklist green.

Rationale: an Embedded Signup went blank on the last step. The code looked right, the network was clean, the provider raised no error. The cause was a **missing flow version** inside `extras`; without it the provider fell back to an old flow that never returned. Found by putting the provider's generated snippet next to ours. Cost a day.

### 7. Contract consistency

Does the same concept arrive in the same shape everywhere:

- **Same-typed fields, same format?** Some dates with a `Z` suffix, some without; money in cents here, in units there; phone with `+90` here, without there.
- **Same concept, same name?** `customerUuid` / `customerId` / `contactUuid` are the same thing, pick one.
- **Nullable consistent?** Required on one endpoint and optional on another becomes a type lie in the frontend.
- **Do list and detail say the same thing?** Does the value on the list row and the value on the detail page come from the same source?

Rationale: an inbox showed the same message at `20:06` in the list and `23:06` in the bubble. Both places called **the same function with the same parameter**; the difference was in the input. `lastMessageAt` came without a `Z` suffix, `sentAt` with one. One DTO, two serialisations. No visual review catches this; only putting the two values side by side does.

### 8. Environment and deployment

- If this goes live, is there anything fragile that hits **every customer**? If so, mark it a release gate.
- Environment variables, secrets, infrastructure provisioning needed; who does it?

## Output format

Every scenario carries these three parts:

```
[ID] Title                                     [working | half | missing]

As a <role> I want <action> so that <benefit>.

Accept   Measurable acceptance criterion.
Today    What actually happens; measured, not guessed.
Owner    frontend / backend / devops
```

At the end:

- **Counts** (working / half / missing).
- **Permission matrix**: backend actions × does the frontend ask × today's result.
- **Order**: release gates first, then what leaves daily use incomplete, then next round.

If the report is long, publish it as a shareable document (an Artifact); the issue tracker gets a link.

## Sibling skills

| Skill | When |
|---|---|
| `/real-grill` | Sharpen the idea before the gate |
| `/real-feature-gate` | Before writing code |
| `/real-module-audit` | Missing scenarios in a built module (this skill) |
| `/real-design-audit` | Screen is done; visual + DESIGN.md check |
| `/real-perf-audit` | Dependency added, before release |
