---
name: real-brainstorm
description: "Generate and narrow options before anything is planned: product ideas, content angles, names, strategy, campaigns. Use for brainstorm, beyin fırtınası, fikir üret or when no candidate exists yet. Ends in one recommendation; hands an approved option to real-plan. (v0.10.0)"
license: MIT
metadata:
  author: Giray Batıtürk
  version: 0.10.0
  source: https://github.com/giraybatiturk/skills
---

# Real brainstorm

Use this when the options themselves are missing. If a candidate already exists and needs shaping, use `real-plan`; if the decision depends on current external facts, use `real-research` first. Follow the open, explore, close sequence (Gray, *Gamestorming*) and keep the three stages visibly separate.

## Frame

State the question in one sentence, the audience or user it serves, and the success signal that would make an idea good. Reuse what the conversation, `PRODUCT.md` or supplied material already establishes; do not ask the user to repeat it. If purpose, audience or a hard constraint (deadline, budget, channel, policy) is unknown and changes which ideas are valid, ask at most 1–3 independent questions with concise choices and a recommendation, then stop. Otherwise continue and list the assumptions you made.

## Open (diverge)

Produce 10–15 distinct ideas with no judgment in this stage. Force range by covering at least four angles:

- the obvious answer done well
- the opposite or inversion of the obvious answer
- borrowed from an adjacent domain or competitor pattern (label the source; unverified patterns are hypotheses)
- the smallest version that could ship or run this week
- the ambitious version if the main constraint disappeared
- a user-voice angle: what the audience would say or ask for in their own words

One line per idea. No near-duplicates: merge ideas that differ only in wording.

## Explore

Cluster the ideas into 3–5 groups and name each group. Pick the strongest 3–5 candidates across groups. For each candidate give one line each:

- **Why it could work**, tied to the success signal
- **Key assumption** that must be true
- **Risk or cost**
- **Cheapest test** that would confirm or kill the assumption

Keep evidence and inference apart: an idea is not validated because it sounds plausible. Mark anything based on external facts you have not checked as unverified.

## Close (converge)

Score the candidates against 2–4 explicit criteria that follow from the frame (for example impact on the success signal, effort, reversibility, fit with constraints). Show the scores in a compact table only when there are three or more candidates.

Lead the final answer with **one recommendation**, then the runner-up and why it lost. Add a **change-my-mind condition**: the specific evidence that would make you switch. Do not end with "it depends" or hand the choice back without a position.

## Output and handoff

Chat order: recommendation first, then the shortlist with assumptions and tests, then the full idea list collapsed at the end. Keep it scannable; no warm-up paragraph.

If the user approves a candidate that is a product or code change, invoke `real-plan` with the chosen idea, frame and assumptions so discovery does not restart. Content, naming or strategy outcomes end here with the next concrete action. Do not implement, publish or send anything from this workflow.

For a group session, the same stages work as a facilitation script: time-box Open, collect ideas silently before discussion, then dot-vote in Close. Offer this only when the user says others are involved.
