---
name: real-brainstorm
description: "Generate ideas or stress-test one: feature ideas for a product, a business or content idea, names, strategy. Researches existing products, competitors, pricing and willingness to pay; agents debate with 5 Whys and a separate judge picks. Use for brainstorm, beyin fırtınası, fikir üret, 'şöyle bir şey yapsak', 'ne özellik geliştirelim'. For shaping an already chosen change use real-plan. (v0.10.0)"
license: MIT
metadata:
  author: Giray Batıtürk
  version: 0.10.0
  source: https://github.com/giraybatiturk/skills
---

# Real brainstorm

Use this when options are missing, or when one idea must be judged on whether it would work, earn and sell. If a candidate is already chosen and needs scope, use `real-plan`. A single factual question ("what does competitor X charge?") belongs to `real-research`.

The spine is open → explore → close (Gray, *Gamestorming*). Generation and judgment stay separate: the model that produced ideas does not pick the winner.

## Step 0: depth and frame

Ask the depth first, in the same message as any framing questions (at most three questions in total, each with short choices and a recommendation):

- **Quick:** one agent, no web research, about 15 ideas, closes with its own assessment and states that it was not independently judged.
- **Deep:** research, independent generators, 5 Whys debate, market card per candidate, separate judge.

Frame in one line each: the question, who benefits (end user or customer), the success signal, hard constraints, and 2–4 judging criteria. Read the project's `PRODUCT.md` and existing analytics or review evidence read-only when available instead of asking for facts you can find.

**Checkpoint 1:** show the frame and criteria and wait for confirmation or edits. Criteria are fixed before any idea is generated.

## Step 1: research (deep)

Before generating, gather current evidence in parallel: existing products and competitors, their prices and packaging, user complaints and praise in reviews, precedents that succeeded or failed, and the product's own usage data if accessible. Follow `real-research` rules for sources (primary sources, dated, verified vs inferred). Read `references/market.md` for what to collect. Novelty search covers market products and competitors only, not patents or papers.

If `real-research` or web tools are unavailable, say so, label every market claim unverified and offer Quick mode.

## Step 2: open (diverge)

Read `references/techniques.md`. Deep mode dispatches three generator agents that do not see each other's output, each with a different technique set, each using draft → bolder → expand. Pool, remove near-duplicates, keep 25–30. Quick mode runs the same techniques in one pass. Treat the most obvious idea as a baseline to beat, not a candidate.

## Step 3: explore

Cluster into named groups and shortlist 4–6 candidates. Keep at least one high-originality candidate, labeled as the wild card, even if it looks less feasible.

**Checkpoint 2:** show the shortlist in one message and ask one question: which to drop or add. The user's context is a criterion the model does not have.

## Step 4: debate (deep)

Read `references/debate.md`. For each candidate the Advocate, Skeptic and Customer agents run two 5 Whys chains (why a customer wants it, why it fails) while the Researcher verifies claims live. Produce a market card per candidate using `references/market.md`.

## Step 5: judge

Deep mode: a separate judge agent that is not told which agent or technique produced an idea compares candidates pairwise against the fixed criteria, each pair in both orders. Disagreement between the two orders is reported as a tie, not resolved by the judge's preference.

## Step 6: close

Lead with **one recommendation**, then the runner-up and why it lost, the **change-my-mind condition**, and the **cheapest test** that would confirm or kill it. Revenue appears only as a range with its assumptions.

**Checkpoint 3:** the user decides. If the choice is a product or code change, hand it to `real-plan` with frame, evidence and assumptions so discovery does not restart. Nothing is implemented, published, priced or sent from this workflow.

## Output

Chat: decision first, then the shortlist with one line of evidence each; no warm-up paragraph. Write the full record (frame, sources, all ideas, 5 Whys chains, market cards, judge results) to one local report following the shared Real Audit `references/reporting.md` conventions, at `docs/brainstorm/YYYY-MM-DD-<slug>.md` in the current project unless the user names another place. Link it in chat.

## Dependencies and limits

Resolve `real-audit` and `real-research` from the client's skill catalog or adjacent directories. Their files are read-only for this workflow: never edit them to fit brainstorm needs; put brainstorm-specific rules in this skill's references. Follow Real Audit `references/orchestration.md` for dispatch, independence and verifier capability. If agents are unavailable, run the tracks serially, disclose it and do not claim independent judgment.

Keep evidence and inference apart. Precedent is not proof, a plausible idea is not validated, and a price from a competitor is not willingness to pay for this product.
