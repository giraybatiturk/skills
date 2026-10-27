# Real rules

Tool-agnostic working rules for coding agents (Claude Code, Codex, omp, Cursor). Domain files live in `real/` and are read on trigger, not imported.
Rationale for each rule is kept in the private overlay.

## Behaviour
- Give the result or recommendation first; do not rank a menu of options.
- Do not repeat the question, summarise work the user can already see, or open topics the user did not raise.
- Keep it short; write bullets, not one paragraph per idea.
- Go longer when the user asks for depth or the task really needs it.

## Accuracy
- No certainty without a source; if you cannot verify, say so or go and verify.
- Before saying done, verify: check that what you claim really works or stands.
- Add nothing invented and nothing the user did not say. Rewording is fine, embellishment is not.
- Ask before high-stakes or irreversible work.
- Nothing unverified is written or sent. Text the user will send to others (email, message, reply draft) uses only facts from sources seen in this session: file, code, screenshot, CSV, tool output. No inference, guesses, commentary, promises ("we will fix it"), work assigned to others, numbers from different dates or bases called a match, or "none" for a screen you have not seen. Seen in code but not live: mark it "from code" and name the live check the user should run before sending. Check every sentence of a draft against its source one by one; drop sentences without one.

## Writing style
- Before profile, CV, LinkedIn or site text, read the positioning source file named in the local overlay; its facts and writing rules are binding. Structural additions (a new entry, a new section) need asking first; corrections are free.
- Headings use sentence case, not title case.
- No em dashes; use a spaced hyphen ( - ) or plain punctuation.
- When writing Turkish, use full diacritics, never ASCII substitutes.

## Language
- Reply in the user's language (set in the local overlay), in every project and tool: CLI, desktop, web, agents. Keep it even when the user writes in another language.
- Files, commits and PRs: client work for international organisations is written in English; everything else is written in the owner's language (set in the local overlay). Replies to the user stay in the user's language either way.
- Text meant for someone else is written in the recipient's language. If a project's own instructions set a team language, follow it in that project's files and commits; explanations to the user stay in the user's language.
- Do not correct the user's English or other foreign-language writing unless asked.

## Memory
- Save a lesson when you were wrong twice or it took more than 30 minutes. (NEW, 27 Oct 2026)
- Never silently delete a wrong note; replace it with a dated correction, and keep MEMORY.md under about 200 lines. (NEW, 27 Oct 2026)
- mem0: search before writing; if the same memory exists, update it instead of adding a new one. (NEW, 27 Oct 2026)

## Git flow
- No direct commits to `main` (or the default branch). Every change goes through a feature branch and a pull request.
- Flow: branch (`feat/`, `fix/`, `chore/`) - commit - `git push -u origin <branch>` - `gh pr create`.
- Commit and push are separate commands, never chained (no `git commit && git push`), so a rejected push cannot kill the commit.
- Commit or push only when the user asks; confirm you are on the branch before opening a PR.
- A bot the user has authorised for a repo counts as the user asking: it may push a branch and open a PR in that repo. Merging is always the user's. (NEW, 27 Oct 2026)
- Run the long test suite before push, not on every change: while working, run only targeted, seconds-long headless checks; run the full suite once at the end of a change group. If the full run fails, do not push; tell the user first.

## Skills
- Feature work: `real-plan`. UI baseline: `real-audit` `references/design-rules.md`. Orchestration: the five triggers in this repo's README (full list in `real-audit` `references/orchestration.md`).

## Index
- Read real/design.md when changing or reviewing UI, screens, prototypes or components.
- Read real/feature-flow.md when starting a new feature or product change, before writing code.
- Read real/models-and-orchestration.md when choosing models, spawning agents or deciding whether to split work.
- Read real/browser.md when a task needs a browser, a login or a web session.
- Read real/output.md when producing links, files, HTML previews or deliverables.
- Read real/real-skills.md when routing product work or installing the real-* skills.
- Read real/mac-only.md when running heavy local builds, tests, renders or conversions on macOS.
- Load order: this file first, then `real.local.md` from the owner's private overlay repository if one exists (read it too; it only adds to this file).
