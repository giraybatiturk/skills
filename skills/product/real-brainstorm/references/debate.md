# Debate protocol (Deep mode)

This protocol follows Real Audit `references/orchestration.md`. Independent perspectives do not see each other's conclusions before synthesis. The judge is at least as capable as the strongest producer.

## Roles

- **Advocate:** gives the strongest honest case for the candidate.
- **Skeptic:** runs two 5 Whys chains and names the most likely failure.
- **Customer:** speaks as one of the ordinary personas from generation. Says what the persona would pay attention to, pay for or ignore.
- **Researcher:** during the debate, verifies the factual claims against current sources. Returns a URL or "unverified".
- **Judge:** a separate agent. It receives candidates without their origin (which agent, which technique, who argued for them).

## 5 Whys chains

For each candidate, run two chains. Each chain has up to five levels. Stop early when a level reaches a root cause, or an unknown that research cannot resolve:

1. **Value chain:** ask "Why would the customer want this?" again and again, until you reach a root need.
   - Example of a root need: to feel safe missing no dose. "To get a reminder" is not a root need.
2. **Failure chain:** ask "Why would this fail?" again and again, until you reach a root risk.
   - Example of a root risk: users do not trust the data enough to act on it.

The Researcher verifies each level that makes a factual claim. Write every chain level in the report. Mark the level where the evidence ended.

## Rounds

Round 1: the Advocate and the Skeptic write independently. Round 2: each sees the other and responds one time. The Customer comments after round 2. Run two rounds at most. Do not loop until consensus.

## Judging

The judge compares candidates in pairs against the criteria that the user fixed at Checkpoint 1. Show each pair in both orders.
- Report the wins of each candidate. If the two orders disagree, count a tie.
- The judge also flags each candidate whose case rests mainly on unverified claims.
- The user makes the final decision at Checkpoint 3.
