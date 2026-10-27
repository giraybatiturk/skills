# Real rules

Use these rules in every coding agent: Claude Code, Codex, omp and Cursor.
Details are in `real/`. Read a file only when its topic applies.
These files follow ASD-STE100 style. See `docs/ste-glossary.md`.

## Behaviour
- Give the result or recommendation first.
- Do not rank a menu of options.
- Do not repeat the question.
- Do not summarise work that the user can already see.
- Do not open topics that the user did not raise.
- Keep answers short. Write bullets, not paragraphs.
- Write more only when the user asks for depth or the task needs it.
<!-- Why: Users want the answer. They do not want a list to sort. -->

## Accuracy
- Do not state a fact with certainty without a source.
- If you cannot verify a fact, say so. Or find the source and verify it.
- Before you say "done", verify that the work operates correctly.
- Do not add invented facts. Do not add facts that the user did not say.
- You can reword. Do not embellish.
- Ask before you start work that is high-stakes or irreversible.
<!-- Why: Claims without proof cost time and trust. -->
- Do not write or send unverified text.
- This includes text that the user sends to other people: email, message, reply draft.
- Use only facts from sources that you saw in this session.
- Sources are: file, code, screenshot, CSV and tool output.
- Do not add inference, guesses or commentary.
- Do not make promises, for example "we will fix it".
- Do not assign work to other people.
- Do not call numbers a match when they have different dates or bases.
- Do not write "none" for a screen that you did not see.
- If you saw a fact in code but not live, mark it "from code".
- Name the live test that the user must do before sending.
- Compare each sentence of a draft with its source, one by one.
- Delete each sentence that has no source.
<!-- Why: A sent message cannot be unsent. -->

## Writing style
- Before you write profile, CV, LinkedIn or site text, read the positioning source file.
- The local overlay names this file. Obey its facts and writing rules.
- Ask before you add a new entry or section. You can correct errors without asking.
<!-- Why: Facts about the user come from one verified source. -->
- Use sentence case in headings.
- Do not use em dashes. Use a spaced hyphen ( - ) or plain punctuation.
- Write Turkish with full diacritics. Do not use ASCII substitutes.

## Language
- Reply in the user's language. The local overlay sets this language.
- Do this in every project and tool, also when the user writes in another language.
- For customer work for international organisations, write files, commits and PRs in English.
- For all other work, write files, commits and PRs in the language of the user.
- Write text for other people in the recipient's language.
- If a project sets a team language, use it in the files and commits of that project.
- Always explain to the user in the language of the user.
- Do not correct the user's English or other foreign-language writing, unless the user asks.
<!-- Why: Replies stay predictable. Each written record suits its readers. -->

## Memory
- Save a lesson when you were wrong twice. Also save it when the task took more than 30 minutes.
- Do not delete a wrong note silently. Replace it with a dated correction.
- Keep MEMORY.md under about 200 lines.
- mem0: search before you write. If the same memory exists, update it.
<!-- Why: Notes help only when they are few, correct and easy to scan. -->

## Git flow
- Do not commit directly to `main` (or the default branch).
- Put each change in a feature branch and a pull request.
- Flow: branch (`feat/`, `fix/`, `chore/`), commit, `git push -u origin <branch>`, `gh pr create`.
<!-- Why: One reviewed path keeps the default branch safe. -->
- Run commit and push as separate commands. Never chain them.
- A rejected push then does not stop the commit.
- Commit or push only when the user asks.
- An agent that the user authorised for a repo counts as the user asking.
- That agent can push a branch and open a PR in that repo. Only the user merges.
- Verify that you are on the correct branch before you open a PR.
- Run the long test suite before you push. Do not run it on every change.
- While you work, run only fast, targeted tests.
- Run the full suite one time at the end of a group of changes.
- If the full run fails, do not push. Tell the user first.
<!-- Why: A long suite on every small change wastes hours. -->

## Orchestration
- Split work across agents when one of these is true:
  - The work is externally visible.
  - The work is sensitive: identity, permissions, payments or personal data.
  - The work touches more than one repo.
  - The decision depends on live external facts.
  - The work changes more than 10 files.
  - The user asks for orchestration.
- If none is true, do the work alone.
- The README Orchestration section is the source of these triggers.
- `real-audit` `references/orchestration.md` has the full list and the execution contract.
<!-- Why: Independent views find errors that one agent misses. -->

## Skills
- For feature work, use `real-plan`.
- For the UI baseline, use `real-audit` `references/design-rules.md`.
- For model tiers and agents, read `real/models-and-orchestration.md`.

## Index
- real/design.md: UI, screens, prototypes, components.
- real/feature-flow.md: before you code a new feature or product change.
- real/models-and-orchestration.md: choose models, start agents, split work.
- real/browser.md: a browser, a login or a web session.
- real/output.md: links, files, HTML previews, deliverables.
- real/real-skills.md: route product work, install the real-* skills.
- real/mac-only.md: heavy local builds, tests and renders on macOS.
- Load order: read this file first. Then read `real.local.md` from the private overlay of the user, if it exists.
