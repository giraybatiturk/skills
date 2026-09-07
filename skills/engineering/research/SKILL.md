---
name: research
description: Investigate a question against high-trust primary sources and capture the findings as a Markdown file in the repo. Use when the user wants a topic researched, docs or API facts gathered, or reading legwork delegated to a background agent.
---

> **Adapted for this repo.** Source: [mattpocock/skills](https://github.com/mattpocock/skills) (MIT), taken as-is. House rules that apply on top:
> - Measure, don't guess: evidence from the repo and the running system; write "could not measure" when you couldn't.
> - New features go through the `/feature-gate` five-heading gate before any code; this skill does not replace that gate.
> - Issue tracker and labels are read from `docs/agents/` (`/setup`).
> - `/start` is the map of the whole flow; `/start` and `/ask-matt` no longer exist.

Spin up a **background agent** to do the research, so you keep working while it reads.

Its job:

1. Investigate the question against **primary sources** (official docs, source code, specs, first-party APIs), not a secondary write-up of them. Follow every claim back to the source that owns it.
2. Write the findings to a single Markdown file, citing each claim's source.
3. Save it where the repo already keeps such notes; match the existing convention, and if there is none, put it somewhere sensible and say where.
