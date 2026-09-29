# Debate protocol (Deep mode)

Follows Real Audit `references/orchestration.md`: independent perspectives do not see each other's conclusions before synthesis; the judge is at least as capable as the strongest producer.

## Roles

- **Advocate:** argues the strongest honest case for the candidate.
- **Skeptic:** drives two 5 Whys chains and names the most likely failure.
- **Customer:** speaks as one of the ordinary personas from generation; says what they would pay attention to, pay for or ignore.
- **Researcher:** checks factual claims raised in the debate against current sources during the debate, returns a URL or "unverified".
- **Judge:** separate agent, receives candidates stripped of their origin (which agent, which technique, who argued for them).

## 5 Whys chains

For each candidate run two chains, each up to five levels, stopping early when a level reaches a root cause or an unknown that research cannot resolve:

1. **Value chain:** "Why would the customer want this?" repeated until a root need is reached (for example: to feel safe missing no dose, not "to get a reminder").
2. **Failure chain:** "Why would this fail?" repeated until a root risk is reached (for example: users do not trust the data enough to act on it).

Each level that makes a factual claim gets a Researcher check. Write every chain level in the report; mark the level where evidence ran out.

## Rounds

Round 1: Advocate and Skeptic write independently. Round 2: each sees the other and responds once. The Customer comments after round 2. Two rounds maximum; do not loop until consensus.

## Judging

Pairwise comparisons against the criteria fixed at Checkpoint 1, each pair presented in both orders. Report wins per candidate; order disagreement counts as a tie. The judge also flags any candidate whose case rests mainly on unverified claims. The user makes the final call at Checkpoint 3.
