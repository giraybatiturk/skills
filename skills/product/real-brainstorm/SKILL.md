---
name: real-brainstorm
description: "Generate ideas or stress-test one: feature ideas for a product, a business or content idea, names, strategy. It researches existing products, competitors, pricing and willingness to pay. Agents debate with 5 Whys and a separate judge picks. Use for brainstorm, beyin fırtınası, fikir üret, 'şöyle bir şey yapsak', 'ne özellik geliştirelim'. To shape a change that is already chosen, use real-plan. (v0.10.0)"
license: MIT
metadata:
  author: Giray Batıtürk
  version: 0.10.0
  source: https://github.com/giraybatiturk/skills
---

# Real brainstorm

Use this when options are missing, or when you must judge one idea on whether it would work, earn and sell.
- If a candidate is already chosen and needs scope, use `real-plan`.
- A single factual question ("what does competitor X charge?") belongs to `real-research`.

The spine is open → explore → close (Gray, *Gamestorming*). Keep generation and judgment separate. The model that produced the ideas does not pick the winner.

## Step 0: depth and frame

Ask the depth first, in the same message as any framing questions. Ask at most three questions in total. Give each question short choices and a recommendation.

- **Quick:** one agent, no web research, about 15 ideas. It closes with its own assessment and states that no independent judge assessed it.
- **Deep:** research, independent generators, 5 Whys debate, market card for each candidate, separate judge.

Frame in one line each: the question, who benefits (end user or customer), the success signal, hard constraints, and 2–4 judging criteria.
- Read the `PRODUCT.md` of the project and the existing analytics or review evidence read-only, when available. Do not ask for facts that you can find.

**Checkpoint 1:** show the frame and criteria. Wait for the user to accept them or edit them. Fix the criteria before you generate any idea.

## Step 1: research (deep)

Before you generate, gather current evidence in parallel:
- existing products and competitors
- their prices and packaging
- user complaints and praise in reviews
- precedents that succeeded or failed
- the usage data of the product itself, if you can access it

Follow the `real-research` rules for sources (primary sources, dated, verified vs inferred).
- Read `references/market.md` to find what to collect.
- Novelty search covers market products and competitors only. It does not cover patents or papers.

If `real-research` or web tools are not available, say so. Label every market claim unverified. Offer Quick mode.

## Step 2: open (diverge)

Read `references/techniques.md`.
- Deep mode starts three generator agents that do not see each other's output. Each agent uses a different technique set. Each agent uses draft → bolder → expand.
- Pool the ideas, delete near-duplicates and keep 25–30.
- Quick mode runs the same techniques in one pass.
- Treat the most obvious idea as a baseline to beat, not as a candidate.

## Step 3: explore

Cluster the ideas into named groups. Make a shortlist of 4–6 candidates.
- Keep at least one high-originality candidate. Label it the wild card, even if it looks less feasible.

**Checkpoint 2:** show the shortlist in one message. Ask one question: which candidate to drop or add. The context of the user is a criterion that the model does not have.

## Step 4: debate (deep)

Read `references/debate.md`.
- For each candidate, the Advocate, Skeptic and Customer agents run two 5 Whys chains: why a customer wants it, and why it fails.
- At the same time, the Researcher verifies claims live.
- Produce a market card for each candidate with `references/market.md`.

## Step 5: judge

Deep mode: use a separate judge agent. Do not tell it which agent or technique produced an idea.
- The judge compares candidates in pairs against the fixed criteria. Each pair goes in both orders.
- If the two orders disagree, report a tie. Do not resolve it with the preference of the judge.

## Step 6: close

Give **one recommendation** first. Then give the runner-up and why it lost, the **change-my-mind condition**, and the **cheapest test** that would prove or kill the recommendation. Show revenue only as a range with its assumptions.

**Checkpoint 3:** the user decides.
- If the choice is a product or code change, hand it to `real-plan` with the frame, evidence and assumptions. Then discovery does not restart.
- This workflow does not implement, publish, price or send anything.

## Output

Chat: give the decision first, then the shortlist with one line of evidence for each candidate. Do not write a warm-up paragraph.
- Write the full record to one local report. The record has the frame, sources, all ideas, 5 Whys chains, market cards and judge results.
- Follow the shared Real Audit `references/reporting.md` conventions.
- Save the report at `docs/brainstorm/YYYY-MM-DD-<slug>.md` in the current project, unless the user names another place. Link it in chat.

## Dependencies and limits

Resolve `real-audit` and `real-research` from the skill catalog of your tool or from adjacent folders.
- This workflow reads their files only. Never edit them to fit brainstorm needs. Put brainstorm-specific rules in the references of this skill.
- Follow Real Audit `references/orchestration.md` for dispatch, independence and verifier capability.
- If agents are not available, run the tracks in series. Disclose it. Do not claim independent judgment.

Keep evidence and inference apart.
- Precedent is not proof.
- A plausible idea is not validated.
- A price of a competitor is not the willingness to pay for this product.
