# Feature flow

Analyse before you write code.
The gate is in the `real-plan` skill: five headings, measurable acceptance criteria, approval before implementation.
This file lists the five headings so that none is lost.

## The five headings
1. User story: the wanted behaviour in the words of the user, with an acceptance criterion.
2. Analysis: what the user wants, what exists, what is missing. MEASURED from the repo and the running system, never guessed.
3. Backend scope: endpoints, fields, permissions, error codes. Say if each is existing or new.
4. Frontend scope: screens, states (empty, loading, error), copy, languages, variants.
5. Connection: where the two meet. Address, body, headers, CORS, timeouts, build and deploy limits.

## Extra rules
- Do not skip this order. If the user says "keep it quick", shorten it. Do not skip it.
- Show the five headings to the user. Get approval before you change any file. You can read files for the analysis.
- If you cannot verify something, write "could not measure" in the analysis. Examples: backend contract, allow list, third-party behaviour.
- Name who will verify it.
<!-- Why: Code first leaves the backend missing or the contract wrong. The error then shows up live. -->
