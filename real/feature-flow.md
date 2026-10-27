# Feature flow

Analyse before writing code.
The gate lives in the `real-plan` skill: five headings, measurable acceptance criteria, approval before implementation.
This file lists the five headings so none is lost.

## The five headings
1. User story: the wanted behaviour in the user's words, with an acceptance criterion.
2. Analysis: what is wanted, what exists, what is missing. MEASURED from the repository and the running system, never guessed.
3. Backend scope: endpoints, fields, permissions, error codes; existing or new.
4. Frontend scope: screens, states (empty, loading, error), copy, languages, variants.
5. Connection: where the two meet: address, body, headers, CORS, timeouts, build and deploy limits.

## Extras
- Never skip this order. If the user says "keep it quick", shorten it; do not skip it.
- Show the five headings to the user. Get approval before opening any file.
- Cannot verify something (backend contract, allow list, third-party behaviour)? Write "could not measure" in the analysis. Name who will verify it.
<!-- Why: Starting with code leaves the backend missing or the contract wrong, and the bug shows up live. -->
