# Feature flow

Analyse before writing code. The gate itself lives in the `real-plan` skill (five headings, measurable acceptance criteria, approval before implementation). This file lists the five headings so none is lost, and keeps only the deltas.

## The five headings
1. User story - the wanted behaviour in the user's words, with an acceptance criterion.
2. Analysis - what is wanted, what exists today, what is missing. MEASURED from the repository and the running system, never guessed.
3. Backend scope - which endpoints, fields, permissions and error codes; existing or new.
4. Frontend scope - screens, states (empty, loading, error), copy, languages, variants.
5. Connection - where the two meet: address, body, headers, CORS, timeouts, build and deploy constraints.

## Deltas to the skill
- This order is never skipped. If the user says "keep it quick", shorten it; do not skip it.
- Show the five headings to the user and get approval before opening any file.
- Anything that cannot be verified (backend contract, allow list, third-party behaviour) is written in the analysis as "could not measure", and names who will verify it.
