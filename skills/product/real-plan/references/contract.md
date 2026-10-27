# Contract mode

A contract is the work order of one agent task. It says what to do, where to work and what to leave alone. It also says how to prove that the work is done.

Use this mode in two cases.
- The approved plan will change more than 3 files.
- The user asks for a contract, or for a work order for an agent.

A small change needs no contract. The contract is local. Do not commit it.

## Where

- Active contract: `.real/contract.md` in the worktree. Each worktree has its own.
- Claims: `.real/claims.md`. The agent writes it.
- Evidence log: `.real/evidence.jsonl`. A hook writes it. The agent never edits it.
- Archive, only when the user asks: `docs/contracts/YYYY-MM-DD-<slug>.md`.
- Tell the user to add `.real/` to `.git/info/exclude` or to the `.gitignore` of the repo.

## Format

Three header lines, then 7 sections with fixed names.

```
Task: <slug>
Status: draft | active | done
Owner: <agent name>

## OBJECTIVE
## CONTEXT
## SCOPE
- src/feature/**
## DO NOT TOUCH
- src/payments/**
## DEPENDENCIES
## EXPECTED OUTPUT
## DONE WHEN
- <measurable item>
```

- OBJECTIVE: one sentence, one result.
- CONTEXT: the files and sources to read first, with paths.
- SCOPE: the paths that the agent can change. One path or glob for each bullet. `*` also matches `/`.
- DO NOT TOUCH: the paths and areas that are off limits. It wins over SCOPE.
- DEPENDENCIES: other tasks, services and keys, and who provides them. Write "none" if there are none.
- EXPECTED OUTPUT: the form of the result: files, a PR or a report.
- DONE WHEN: measurable items. Each item has a way to verify it. Do not write "works well".

## Steps

1. **Draft.** Take the contract text from the approved plan.
   - OBJECTIVE comes from the goal of the plan. CONTEXT comes from its Analysis.
   - SCOPE comes from the Backend scope and the Frontend scope. Use paths that you verified in the repo.
   - DONE WHEN comes from the acceptance criteria. Keep each item measurable.
   - Ask the user for DO NOT TOUCH if the plan does not name it. Typical areas: payments, migrations, secrets, generated files.
2. **Save the draft.** If `scripts/real-contract.sh` is available, run `scripts/real-contract.sh new <slug>` and fill the sections. Otherwise write `.real/contract.md` with the format above. Set `Status: draft`.
3. **Show it.** Show the contract in chat as a table with 7 rows, one for each section. Wait for the answer of the user.
4. **Approval.** Never approve the contract yourself. The user runs `scripts/real-contract.sh approve`. In Claude Code, you can run it, and the user answers the prompt. Without the hooks, set `Status: active` only after the user says yes.
5. **Work.** Change only files in SCOPE. Never change a file in DO NOT TOUCH.
   - If you need a file outside SCOPE, stop. Show the path and the reason to the user.
   - Only an answer of the user changes SCOPE. The user runs `scripts/real-contract.sh add-scope <glob>`.
   - Never edit an active contract or the evidence log.
6. **Prove.** Run the command that proves each DONE WHEN item. With the hooks, each command gets an id in `.real/evidence.jsonl`.
   - Write one line for each item in `.real/claims.md`: `N | done | e3, e5 | note`. `N` is the position of the item in DONE WHEN.
   - If you cannot measure an item, write `N | could-not-measure | | verifier: who can verify it`.
   - Without the hooks, there are no ids. Put the command and its result in the note, and say that no hook recorded them.
7. **Report.** Run `scripts/real-contract.sh report`, or build the same table by hand. Then run `scripts/real-contract.sh done`. It fails while an item is not verified.

## Rules

- An item without evidence is "unverified". Do not say the task is done while an item is unverified.
- Evidence of a failed command is not proof.
- An id that is not in the log is not proof. Do not invent ids.
- Mark an item "could not measure" only with a named verifier.
- DO NOT TOUCH wins when a path is in both lists.
- Never write a token, a key or a private value in the contract or in the claims.

## Report format

The chat message gives the verdict first: verified, partly verified or not verified. Then it shows the table. Then it gives one next action.

| # | DONE WHEN item | Claimed | Verified (evidence id) | Status |
|---|---|---|---|---|

- Claimed: yes, no, or could not measure.
- Verified: the evidence ids that prove the item. A dash if there are none.
- Status: verified, unverified or could not measure.

## Settings and hooks

- The hooks are in `hooks/` of the skills repo. They enforce SCOPE and DO NOT TOUCH, write the evidence log and check the claims when the agent stops. `hooks/README.md` has the settings.
- By default, work on more than 3 changed files needs a contract. Set `contract.required` to `always` or `off` in the `.real-hooks` file to change that.
- Claude Code asks the user for an edit outside SCOPE. Codex and omp block it.
- The hooks are a guardrail, not a boundary. The user and CI are the final check.
