---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

> **Adapted for this repo.** Source: [mattpocock/skills](https://github.com/mattpocock/skills) (MIT), taken as-is. House rules that apply on top:
> - Measure, don't guess: evidence from the repo and the running system; write "could not measure" when you couldn't.
> - New features go through the `/feature-gate` five-heading gate before any code; this skill does not replace that gate.
> - Issue tracker and labels are read from `docs/agents/` (`/setup`).
> - `/start` is the map of the whole flow; `/start` and `/ask-matt` no longer exist.

Implement the work described by the user in the spec or tickets.

Use /tdd where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, use /code-review to review the work.

Commit your work to the current branch.
