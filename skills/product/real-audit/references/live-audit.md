# Auditing a live system

Read this before you inspect a running production system with real users and real data. It applies to every mode.
- `quality.md` and `security.md` already forbid destructive, payment and personal-data mutations against live systems.
- This reference covers the quieter ways that an audit changes the system that it measures.

The governing rule: **an audit observes; it must not alter state, consume the user's budget, or leave residue.**
- Navigation, reading, opening a menu and taking a screenshot are observation.
- Anything that writes, sends, charges, generates or notifies is not observation, however small it looks.

## Before starting

- Establish if the target is production, staging or a disposable environment. Record it in the environment section of the report. A finding that you measured in staging does not establish production behaviour. The reverse is also true.
- Establish whose account you use and with what role. An audit from an administrator account cannot show what an ordinary user sees.
- When a finding depends on a permission boundary, it needs a second account at the relevant role. Without one, record the finding as unverified and name who can run it.
- Agree what is off limits before you open the product, not after a dialog appears.

## What counts as a side effect

Treat all of these as actions, not observations:

- **Writes:** submitting a form, saving a draft, creating or deleting a record, changing a setting, uploading a file.
- **Outbound messages:** notifications, invitations, emails, webhooks, anything that reaches a person or another system.
- **Charges and quota:** payments, credits, per-seat consumption.
- **Model calls.** In an AI product, a question to the assistant is a write. It spends the tokens of the account, creates a conversation record, appears in cost and usage tables, and can train or seed caches.
  - If you audit answer quality by querying the live product, you contaminate the usage data that the audit reports on.
  - Use recorded evidence, existing evaluation sets or an isolated environment.
  - If none exists, record answer quality as unverified and name the verifier. Do not generate fresh load.
- **Expensive reads.** A query that returns far more than the interface normally requests is a load event, although it writes nothing. Examples: a large page-size parameter, an unbounded export. Use it once at most, deliberately, and say so in the report.

## Automation discipline

- Drive the product one deliberate step at a time. **Never click elements in bulk**. Example of bulk clicking: iterating over every button on the page to expand a menu. Eventually one of them sends, deletes or submits something. If a collapsed navigation must be opened, open the specific control.
- Do not fire keyboard shortcuts blindly. A shortcut can be bound to a destructive action.
- Avoid anything that opens a native dialog. A modal alert blocks the automation channel. A human must clear it.
- If an unintended action occurs, stop and record exactly what happened. Tell the user in the report and in the session. An accidental action that you do not report is worse than the action itself.

## The audit changes the data it measures

Browsing a product generates traffic. Page views, session counts, active-user tallies, per-app hit counters and cost dashboards all absorb the activity of the auditor. An inventory pass over a few hundred screens is clearly visible in a daily figure.

When the report uses usage or cost data from the audit window, state that the figures include audit traffic. Give the approximate scale.
- Prefer a period that ends before the audit began.
- Never present a counter that the audit inflated as evidence of user behaviour.

## Leave nothing behind

Anything that you write to make measurement possible is residue.
- Examples: values in browser storage, temporary preferences, an opened side panel, a changed filter, a resized window.
- Remove them at the end of the session. Verify the removal.
- Injected styles or scripts that you use to force a render must be temporary. Never describe them as the own behaviour of the product.

## Record the boundary

The environment section of the report states which tests you could not run without side effects, and who can run them safely. A test that you skipped to protect a live system is unverified coverage with a clear reason. It is not a passing result. It is not an absent requirement.
