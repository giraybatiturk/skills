# Auditing a live system

Read this before inspecting a running production system with real users and real data. It applies to every mode. `quality.md` and `security.md` already forbid destructive, payment and personal-data mutations against live systems; this reference covers the quieter ways an audit changes the system it is measuring.

The governing rule: **an audit observes; it must not alter state, consume the user's budget, or leave residue.** Navigation, reading, opening a menu and taking a screenshot are observation. Anything that writes, sends, charges, generates or notifies is not, regardless of how small it looks.

## Before starting

- Establish whether the target is production, staging or a disposable environment, and record it in the report's environment section. A finding measured in staging does not establish production behaviour, and the reverse is also true.
- Establish whose account is being used and with what role. An audit run from an administrator account cannot demonstrate what an ordinary user sees. When a finding depends on a permission boundary, it needs a second account at the relevant role; without one, record it unverified and name who can run it.
- Agree what is off limits before opening the product, not after a dialog appears.

## What counts as a side effect

Treat all of these as actions, not observations:

- **Writes:** submitting a form, saving a draft, creating or deleting a record, changing a setting, uploading a file.
- **Outbound messages:** notifications, invitations, emails, webhooks, anything that reaches a person or another system.
- **Charges and quota:** payments, credits, per-seat consumption.
- **Model calls.** In an AI product, asking the assistant a question is a write: it spends the account's tokens, creates a conversation record, appears in cost and usage tables, and may train or seed caches. Auditing answer quality by querying the live product contaminates the very usage data the audit reports on. Use recorded evidence, existing evaluation sets or an isolated environment; if neither exists, record answer quality as unverified and name the verifier rather than generating fresh load.
- **Expensive reads.** A query that returns far more than the interface normally requests (a large page-size parameter, an unbounded export) is a load event even though it writes nothing. Use it once at most, deliberately, and say so in the report.

## Automation discipline

- Drive the product one deliberate step at a time. **Never click elements in bulk**, for example by iterating over every button on the page to expand a menu: one of them will eventually send, delete or submit something. If a collapsed navigation must be opened, open the specific control.
- Do not fire keyboard shortcuts blindly; a shortcut can be bound to a destructive action.
- Avoid anything that opens a native dialog. A modal alert blocks the automation channel and needs a human to clear it.
- If an unintended action does occur, stop, record exactly what happened, and tell the user in the report and in the session. An unreported accidental action is worse than the action itself.

## The audit changes the data it measures

Browsing a product generates traffic. Page views, session counts, active-user tallies, per-app hit counters and cost dashboards all absorb the auditor's own activity. An inventory pass over a few hundred screens is plainly visible in a daily figure.

When the report uses usage or cost data from the audit window, state that the figures include audit traffic and give the approximate scale. Prefer a period that ends before the audit began. Never present a counter the audit inflated as evidence of user behaviour.

## Leave nothing behind

Anything written to make measurement possible is residue: values placed in browser storage, temporary preferences, an opened side panel, a changed filter, a resized window. Remove them at the end of the session and confirm removal. Injected styles or scripts used to force a render must be temporary and must never be described as the product's own behaviour.

## Record the boundary

The report's environment section states which checks could not be run without side effects, and who can run them safely. A check skipped to protect a live system is unverified coverage with a clear reason, not a passing result and not an absent requirement.
