---
name: real-implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

> **Local workflow rules:**
> - Measure, don't guess: evidence from the repo and the running system; write "could not measure" when you couldn't.
> - New features go through the `/real-feature-gate` five-heading gate before any code; this skill does not replace that gate.
> - Issue tracker and labels are read from `docs/agents/` (`/real-setup`).
> - `/real-start` is the map of the whole flow; `/real-start` and `/start` no longer exist.

Implement the work described by the user in the spec or tickets.

Use /real-tdd where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, use /real-code-review to review the work.

Commit your work to the current branch.
