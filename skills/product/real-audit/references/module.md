# Module audit mode

Argument: module or feature name (for example `messaging`, `appointments`, `payments`). Infer it from the request and the supplied artifacts. Ask only if several plausible targets change the scope materially.

**When to run**

- You touch a module for the **second time** (you add on top, you do not build from scratch).
- The "why doesn't this work" rounds start. When you find one bug, ask **what else in the same class is broken**.
- **Before going live**: the module works in test and has not reached a customer yet.
- You come back to a module that nobody touched for a while.

This mode runs **after the fact**. It inventories scenarios from code that already exists and marks the gaps. For a feature that is not written yet, `real-plan` produces the five headings.

## Why

If you start coding directly, the **happy path** gets done. Error paths, permission states and state transitions stay missing. The user finds them one by one in production, and each one becomes its own round.

Measured case (a messaging module): 10 of 21 scenarios were missing, and 5 were half done. The user found most of them.
- The unread badge never went down.
- The counter stayed full after a disconnect.
- The error text showed a raw backend code.
- Only one of eight permission actions was implemented.

None of it is visible on the happy path. All of it shows on the second step.

## Flow

0. **Measure, don't guess.** Run the inventories. Write **"could not measure"** in the report for whatever you cannot measure (backend contract, third-party behaviour). Name who verifies. Never assume silently.
1. Produce the inventories (endpoints, permissions, error codes, states).
2. Assess every checklist class for applicability. Write scenarios for the applicable classes. Write a short reason for each class that is not applicable.
3. Write each scenario as **role + action + acceptance criterion**. Then write **what happens today** and the **owner** (frontend / backend / devops).
4. Mark the status. Do not put source-only results in the working totals.
   - `working` (tried end to end)
   - `source-verified` (source establishes the narrow behavior, not runtime integration)
   - `half` (one side ready, the other missing)
   - `missing` (absence verified)
   - `unverified` (required evidence is not available; name the missing evidence and the verifier)
5. Report, release gates first. The order reflects the measured impact. It is not a delivery plan.
   A release gate must follow an applicable product requirement. In a function-only audit, absent caller or server evidence is a scope limit. It is not a new requirement to build a server. It is not a release blocker.
6. With applicable implementation authorization, fix the frontend gaps. Include the backend gaps as one list in the local report. To send them to an issue tracker, you need explicit authorization for that external action.

## Inventories

Derive the commands for the project yourself. Record the discovered paths in the audit report. Propose updates to AGENTS.md/CLAUDE.md separately. Do not edit them during an audit. Seven questions need answers:

```bash
# 1. Endpoints: every URL the module talks to
grep -rnoE "['\"](/?api/)?v[0-9]+/<module>[a-zA-Z/_-]*['\"]" <api-client-dir> | sort -u

# 2. Permission actions: what the backend DEFINED
# If absent from the contract, inspect the permission matrix read-only and record the untested permission path as a coverage gap.
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

Evaluate each class for applicability. Cover the applicable classes. Mark irrelevant classes not applicable with a short reason. A local utility does not need invented endpoints, UI states or multi-user flows.

### 1. Permissions

- Write a separate scenario for **every applicable action** that the backend defines. Unauthorized execution must be rejected at the trusted boundary. Verify the UI behavior against the policy of the product (hidden or disabled with explanation).
- Asking only for the module gate is not enough. Ask separately for `send`, `delete` and `add` INSIDE the screen.
- Test question: "what happens if someone without the permission invokes this action directly?" A hidden button is not authorization. A 403 can be correct enforcement. Assess the visible control separately against its intended UX.

### 2. State transitions (not just the initial state)

- Set up → tear down → set up again. At each step, what does **the rest of the panel** show?
- Establish the meaning of the counter first. Current unread or item counts must decrease when their underlying state changes. Lifetime totals can correctly only grow. Verify resets and updates against that contract.
- Sign out/in, switch account or company, change permission: does the cache hold stale data?
- Do the mutations invalidate the queries that depend on them? If you delete a record, every place that counts it must refresh.

### 3. Error paths

- For **every error code** that the backend can return: is there a dictionary entry, or does the raw code reach the screen?
- How many notifications does one error produce? Global handler + the own handler of the screen = two.
- Inspect the error contract before you judge displayed messages. Untrusted or internal details must not leak. A message that is explicitly user-safe and localized can be displayed. Do not assume that every message field contains a code.
- Network down, timeout, server 500: which text appears?

### 4. Empty and intermediate states

- No data · loading · error · unauthorised · waiting for third-party approval · third party rejected.
- **How many empty-state messages** show at one time on the same screen? If more than one, the user must pick which to read.

### 5. Multiple users and many records

- Do two users open or edit the same record at the same time?
- Is "who did this" visible? In a multi-person account, "who wrote this reply" needs an answer.
- With thousands of records, is search enough, or do you need filters and totals?

### 6. Third-party dependency (if any)

- Is there an approval or review state on the provider side? Can the user see it?
- What if the provider changes its data format? A renamed field can drop data silently.
- How long does the token that we store live? Does it refresh? How does the user notice when it breaks?
- Does the connection survive a server restart?

**Setup verification: compare against the provider's own output.** Most providers have a wizard in their console that generates code "for your app" (for example, official signup builders and payment integration samples). Compare our code **line by line** with what it generates.
- Are the version fields the same? (Flow, SDK and API versions can differ.)
- Is any required parameter missing?
- Is every item in the console checklist green?

Rationale: an Embedded Signup went blank on the last step.
- The code looked right. The network was clean. The provider raised no error.
- The cause was a **missing flow version** inside `extras`. Without it, the provider fell back to an old flow that never returned.
- Found by putting the code snippet that the provider generated next to ours. It cost a day.

### 7. Contract consistency

Does the same concept arrive in the same shape everywhere?

- **Same-typed fields, same format?** Some dates have a `Z` suffix, some do not. Money is in cents here and in units there. Phone has `+90` here and not there.
- **Same concept, same name?** `customerUuid` / `customerId` / `contactUuid` are the same thing. Pick one.
- **Nullable consistent?** If a field is required on one endpoint and optional on another, it becomes a type lie in the frontend.
- **Do list and detail say the same thing?** Do the value on the list row and the value on the detail page come from the same source?

Rationale: an inbox showed the same message at `20:06` in the list and `23:06` in the bubble.
- Both places called **the same function with the same parameter**. The difference was in the input.
- `lastMessageAt` came without a `Z` suffix. `sentAt` came with one. One DTO, two serialisations.
- No visual review catches this. Only a side-by-side view of the two values catches it.

### 8. Environment and deployment

- If this goes live, is there anything fragile that hits **every customer**? If so, mark it a release gate.
- Which environment variables, secrets and infrastructure provisioning are needed? Who does it?

## Output format

Every scenario carries these three parts:

Use neutral scenario IDs such as M1/M2. Assign P0–P3 severity only to verified defects. Never assign it to successful or unverified coverage entries. Keep findings and coverage counts separate.

```
[ID] Title                                     [working | source-verified | half | missing | unverified]

As a <role> I want <action> so that <benefit>.

Accept   Measurable acceptance criterion.
Today    What actually happens; measured, not guessed.
Owner    frontend / backend / devops
```

At the end:

- **Counts** (working / source-verified / half / missing / unverified), with the missing evidence and the verifier for unverified cases.
- **Permission matrix**: backend actions × does the frontend ask × today's result.
- **Order**: release gates first, then what leaves daily use incomplete, then the next round.

If the report is long, write a local document and link it in chat. External publication and issue-tracker writes need explicit authorization for that action.

## Sibling skills

| Skill | When |
|---|---|
| `real-plan` | Sharpen and gate a change before code |
| `real-audit` Product | Whole-product direction and next release |
| `real-audit` Module | Missing scenarios in a built module (this mode) |
| `real-audit` Design | Screen or flow quality |
| `real-audit` Performance | Measured web performance |
