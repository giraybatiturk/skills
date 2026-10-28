# Real rules

Use these rules in every coding agent: Claude Code, Codex, omp and Cursor.
Details are in `real/`. Read a file only when its topic applies.
These files follow ASD-STE100 style. See `docs/ste-glossary.md`.

## Behaviour
- Give the result or recommendation first.
- Do not rank a menu of options.
- Do not repeat the question. Do not summarise work that the user can already see.
- Do not open topics that the user did not raise.
- Keep answers short. Write bullets, not paragraphs.
- Write more only when the user asks for depth or the task needs it.
<!-- Why: Users want the answer. They do not want a list to sort. -->

## Accuracy
- Do not state a fact with certainty without a source.
- If you cannot verify a fact, say so. Or find the source and verify it.
- Before you say "done", verify that the work operates correctly.
- Do not add invented facts or facts that the user did not say. You can reword. Do not embellish.
- Ask before you start work that is high-stakes or irreversible.
- Do not write or send unverified text.
- This includes text that the user sends to other people. Before you draft it, read `real/drafts.md`.
<!-- Why: Claims without proof cost time and trust. A sent message cannot be unsent. -->

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
- For the language of files, commits, PRs and text for other people, read `real/drafts.md`.
<!-- Why: Replies stay predictable. Each written record suits its readers. -->

## Memory
- Save a lesson when you were wrong twice. Also save it when the task took more than 30 minutes.
- Do not delete a wrong note silently. Replace it with a dated correction.
- Keep MEMORY.md under about 200 lines.
- mem0: search before you write. If the same memory exists, update it.

## Git flow
- Do not commit directly to `main` (or the default branch).
- Put each change in a feature branch and a pull request.
- Flow: branch (`feat/`, `fix/`, `chore/`), commit, `git push -u origin <branch>`, `gh pr create`.
- Run commit and push as separate commands. Never chain them. A rejected push then does not stop the commit.
- Commit or push only when the user asks.
- An agent that the user authorised for a repo counts as the user asking.
- That agent can push a branch and open a PR in that repo. Only the user merges.
- Verify that you are on the correct branch before you open a PR.
- Run the long test suite before you push. Do not run it on every change. Details: `real/git-tests.md`.
<!-- Why: One reviewed path keeps the default branch safe. A long suite on every small change wastes hours. -->

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
- Start all product work with `real-start`. It selects the correct real skill.
<!-- Why: One entry point keeps the choice of skill consistent. -->
- For feature work, use `real-plan`.
- For the UI baseline, use `real-audit` `references/design-rules.md`.
- For model tiers and agents, read `real/models-and-orchestration.md`.

## Index
- real/design.md: UI, screens, prototypes, components.
- real/feature-flow.md: before you code a new feature or product change.
- real/models-and-orchestration.md: choose models, start agents, split work.
- real/browser.md: a browser, a login or a web session.
- real/output.md: links, files, HTML previews, deliverables.
- real/drafts.md: text for other people. Language of files, commits and PRs.
- real/git-tests.md: the test suite before a push.
- real/real-skills.md: route product work, install the real-* skills.
- real/mac-only.md: heavy local builds, tests and renders on macOS.
- Load order: read this file first. Then read `real.local.md` from the private overlay of the user, if it exists.
