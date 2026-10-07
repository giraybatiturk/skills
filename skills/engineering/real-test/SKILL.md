---
name: real-test
description: "Test the key user flows of your own web app (local, staging or any URL you own) with persistent Playwright tests: e2e test, uçtan uca test, kullanıcı akışı testi, regression tests, test my app. Uses Playwright's planner, generator and healer agents inside your coding agent: explores the app, shows a plan for approval, writes tests into your repo, runs them at desktop 1280 and phone 375 width, heals failures once and reports passed, failed, fixme and blocked flows. Reruns are plain npx playwright test, no model. Runs on your machine, no API key, no telemetry. Stops before any final submit (send, delete, pay, invite, publish) unless you allow writes on a non-production target. For a rule-based read-only scan of any public URL use real-check; for expert judgment on your own product use real-audit. (v0.12.0)"
license: MIT
metadata:
  author: Giray Batıtürk
  version: 0.12.0
  source: https://github.com/giraybatiturk/skills
---

# Real test

Point it at your own web app and get tests of its key user flows that stay in your repo. It builds on Playwright's official test agents (`npx playwright init-agents`: planner, generator, healer), not on a custom agent. The planner explores the app and writes a plan, the user approves it, the generator writes one Playwright test per scenario, the tests run at desktop (1280 px) and phone (375 px) width, the healer gets one pass at the failures, and the user gets a short report. Afterwards `npx playwright test` reruns everything with no model and no agent. `<skill>` below means the directory that contains this `SKILL.md`; resolve it from the client's skill catalog.

Everything runs on the user's machine inside their coding agent (their subscription, no API key). Besides the app under test and the one-time downloads of setup (npm packages, Chromium), data goes only to the agent's own model provider: page content, snapshots, test code and test data pass through it. Credentials do not: the user logs in themselves (step 3) and no agent opens the session file. This skill adds no telemetry.

Not the other two. `real-check` scans any public URL with fixed rules, no AI, about 30 seconds, read-only, and writes a one-page report for the site's owner. `real-audit` is expert judgment on your own product in depth. `real-test` is for your own app: an AI explores it, writes persistent Playwright tests for its user flows, runs and heals them, and reports passed / failed / fixme / blocked. A green run says the planned flows passed once, at two widths, in Chromium; it is not proof the app works.

## Steps

1. **Parse `$ARGUMENTS`.** Required: the target URL, `http://` or `https://`; otherwise stop and show `/real-test <url> [--flows FILE] [--out DIR] [--lang tr|en] [--allow-writes]`. Lower-case the host; stop if it does not match `^[a-z0-9.-]+(:[0-9]+)?$` (it ends up in folder names and commands; IPv6 literals are not supported). Stop if the URL carries `user:password@` or a query or fragment with a token, key or session: the user logs in as in step 3 instead. Plan and seed use the URL's origin and path only, never its query or fragment. Options:
   - `--flows FILE`: the flows to cover, one per line; read it. The plan covers those and nothing else. Without it the planner picks the key flows, at most 8 scenarios.
   - `--out DIR`: folder for the tests, default `./tests/real-test/` (`<out>` below). Only this skill writes there: the guard checks every code file in it and renames the ones that break a rule. If the project has a tests convention, use `<that folder>/real-test/`, never a folder that already holds the user's tests; say so. `<out>` must be inside the project.
   - Reports go to `./real-test-reports/<host>-<date>/` (`<report>` below; `<host>` with `:` as `-`, `<date>` as `YYYY-MM-DD`, add `-2`, `-3` if the folder exists), or the project's reports convention.
   - `--lang tr|en`: language of the plan and the report. Default: the language of the user's conversation (ask once if it is neither).
   - `--allow-writes`: see Safety. Off by default.

   Done when the URL, flows, folders, language and `--allow-writes` are fixed.

2. **Preflight.**
   - Ask once, for every host: may the user test this app, and is it production? `localhost`, `127.0.0.1`, `*.localhost` and private addresses only make "non-production" the suggested answer: port-forwards, tunnels and internal production apps live there too. Treat no answer as production. Prefer a non-production target. If the user's organisation or client restricts external tools or sending data to model providers, ask before going on. Stop if the user may not test the target.
   - Needs Node 20+, a shell and Chromium. If the client has no shell (for example the Claude app) say exactly that and stop; do not fake results.
   - Playwright: reuse the existing `playwright.config.*` and `@playwright/test`. Otherwise, with the user's consent, `npm install -D @playwright/test`, then `PLAYWRIGHT_SKIP_BROWSER_GC=1 npx playwright install chromium` (both download from the network), then write `playwright.config.ts` (`<origin>` is the target's origin, `<out>` as a relative path; run Playwright from the project root):
     ```ts
     import { existsSync } from 'node:fs';
     import { defineConfig } from '@playwright/test';

     const storageState = '.auth/real-test.json';
     const baseURL = process.env.BASE_URL ?? '<origin>';
     const use = {
       baseURL,
       browserName: 'chromium' as const,
       storageState: existsSync(storageState) ? storageState : undefined,
       trace: 'retain-on-failure' as const,
       screenshot: 'only-on-failure' as const,
     };

     export default defineConfig({
       reporter: [['list'], ['html', { open: 'never' }]],
       projects: [
         { name: 'real-test-desktop', testDir: '<out>', use: { ...use, viewport: { width: 1280, height: 800 } } },
         { name: 'real-test-mobile', testDir: '<out>', use: { ...use, viewport: { width: 375, height: 812 }, isMobile: true, hasTouch: true } },
       ],
     });
     ```
     With `--allow-writes`, also put `const grepInvert = new URL(baseURL).origin === '<origin>' ? undefined : /@writes/;` above `defineConfig` and `grepInvert,` into both projects. Every test of this run carries `@writes` (step 5), so `BASE_URL=<production> npx playwright test` skips them and cannot reach a submit.
     With an existing config, add the same two projects to its `projects` instead (and the `grepInvert` lines if writes are allowed), plus a `testIgnore` for `<out>` on existing projects that would also pick it up. Show the diff and get consent before editing. If the config already has `real-test-*` projects from an earlier run, read their default `baseURL` origin and their `grepInvert` origin: when either is not the target's origin, stop and update both to the target's origin with the user's consent; an earlier target's origin must never stay behind.
   - Add the missing lines to `.gitignore`: `.auth/`, `.playwright-mcp/`, `test-results/`, `playwright-report/`, and the report folder (`real-test-reports/` or the one in use).
   - Seed. Write `<out>/seed.spec.ts` on every run (it is this skill's own file and the agents start every scenario from it; `init-agents` leaves an existing seed alone, so an old one would still open the earlier target): `import { test } from '@playwright/test';` and `test('seed', async ({ page }) => { await page.goto('<path of the target URL, no query or fragment>'); });`.
   - Agents. If `.claude/agents/playwright-test-planner.md` (Codex: `.codex/agents/playwright_test_planner.toml`) is missing, run `npx playwright init-agents --loop=claude --project real-test-desktop` (Codex: `--loop=codex`) once the config exists; it fails on a Playwright without `init-agents`, then update `@playwright/test` with consent. It writes the three agents, `.mcp.json` (Claude) and `specs/`, and it overwrites an existing `.mcp.json` and agent files of the same names: first copy any existing `.mcp.json` aside, and afterwards merge the user's other servers back into the new file, showing the diff.
   - Harden, every time the agents exist, not only after the run above; edit only these entries: in `.mcp.json` add `"--headless"` to the `playwright-test` args and `"env": { "BASE_URL": "<origin>" }` to that server (Codex: `"--headless"` to `args` and `BASE_URL = "<origin>"` under `[mcp_servers.playwright-test.env]` in each `.toml`), so the agents' browser opens the target even when `BASE_URL` is set in the user's shell; in the planner agent remove `mcp__playwright-test__browser_run_code_unsafe` from `tools:` (Codex: `"browser_run_code_unsafe"` from `enabled_tools`). Redo it after every `init-agents` run.
   - Check what will be tested: the config's default `baseURL` origin, the seed's path and the `BASE_URL` in the user's shell (`echo "${BASE_URL-}"`) must agree with the target. A `BASE_URL` of another origin does not go into the briefs or the report runs: the run command in step 6 sets `BASE_URL=<origin>` itself; tell the user it is set.
   - The client loads agents and project MCP servers at session start. If this step created or changed the agents or `.mcp.json`: Claude Code: restart the session in this folder and approve the `playwright-test` server when asked (`/mcp`); Codex: start a new session. Tell the user, give the same `/real-test` command to run again, and stop; the rerun finds everything in place.
   - Otherwise confirm the `playwright-test` tools (`planner_setup_page`, `generator_setup_page`, `test_run`) are available to the agents; if not, the server still needs approval (Claude Code) or the client did not start it for the agent (Codex): say so and stop. Never plan or write tests yourself in an agent's place. The client will ask permission for these tools and for edits under `<out>`; do not bypass its permission system.

   Done when the config, `.gitignore`, seed, hardened agents and available tools are confirmed, or the stop reason has been given.

3. **Auth.** Skip if the app needs no login. If the user says it does, or the planner reports `LOGIN_REQUIRED` (step 4) while `.auth/real-test.json` is missing: stop and have the user log in once themselves with `npx playwright codegen --save-storage=.auth/real-test.json <url>` (log in in the window, then close it). The projects load that file as `storageState`, which the planner, generator and healer browser also uses. Credentials never go into the plan, a test, a brief or this chat. Never open `.auth/` and tell every agent not to; the file holds live session cookies, so it stays git-ignored and the user deletes it when done. A login page showing up later means the session expired: those flows are `blocked`, not `failed`.

   Done when no login is needed or `.auth/real-test.json` exists.

4. **Plan.** If `specs/real-test-plan.md` exists, ask once whether to reuse it (go to the checkpoint) or replace it. Otherwise, or to replace, invoke the `playwright-test-planner` agent (Codex: `playwright_test_planner`) with this brief and the standing rules from Safety:
   - Call `planner_setup_page` once: `project: "real-test-desktop"`, `seedFile: "<out>/seed.spec.ts"`. If the page it opens is not on `<origin>`, save no plan and start the reply with `WRONG_ORIGIN`; then stop and say so.
   - Scenarios: those from `--flows`, otherwise the key user flows, at most 8. Each scenario is independent and starts from a fresh state. Names and steps in the report language, UI text quoted as the app shows it.
   - Save with `planner_save_plan`: `fileName: "specs/real-test-plan.md"`, each test's `file` `<out>/<scenario-slug>.spec.ts` (flat, ASCII, lower case, dashes), the suite `seedFile` the seed.
   - Login wall (password field, 401/403, redirect to a sign-in page) and no `.auth/real-test.json`: do not save a plan; start the reply with `LOGIN_REQUIRED`.
   - Afterwards check that the plan has the `**Seed:**` and `**File:**` lines `planner_save_plan` writes. If not, the agent did not run (a client that cannot start it writes a plan itself): say so and stop.

   **CHECKPOINT.** Show the plan: the target (`<origin><path>`, production or not), two or three lines on what the app is, a table `No | Flow | What it proves | Page`, and what is out of scope (every step that stops before a final submit). If the plan was replaced and `<out>` holds specs the new plan does not list, name them: they keep running and are reported apart (`extra`), not counted; the user may move them out. Ask: write the tests, edit the plan, or stop. Edits go into `specs/real-test-plan.md`; show the table again. Do not generate before an explicit yes.

   Done when the user has approved the plan, or stopped.

5. **Generate.** `mkdir -p <report>`. For each `####` scenario of the approved plan, one after another (they share one browser; never in parallel), invoke `playwright-test-generator` (Codex: `playwright_test_generator`) with `<test-suite>`, `<test-name>`, `<test-file>`, `<seed-file>`, `<body>` taken from the plan, `project: "real-test-desktop"`, the standing rules, and:
   - One test per file, in `test.describe(<suite>)`, titled with the scenario name.
   - Every `expect:` line of the scenario becomes an assertion, written web-first and awaited (`await expect(locator)...`). No fixed waits, `networkidle` or `force: true`.
   - Navigate with paths relative to `baseURL` (`page.goto('/path')`), never with an absolute URL, so the tests can be pointed at another environment. If the page the generator opens is not on `<origin>`, it writes nothing and replies `WRONG_ORIGIN`; then stop and say so.
   - With `--allow-writes`: every `test(...)` carries `{ tag: '@writes' }`.

   Then run `node <skill>/scripts/guard.mjs <out> --plan specs/real-test-plan.md --json <report>/guard-generate.json` (plus `--require-tag @writes` if writes are allowed; the tag is required of the planned specs only). It checks every code and data file in `<out>`, prints one JSON line per finding (never the offending source line) and a summary; exit 1 means it renamed files to `*.rejected`, which Playwright no longer runs. Each rejected or missing scenario is `blocked` in the report, with the rule id (or "generator produced no test"). If the seed is rejected, rewrite it.

   Done when every approved scenario has a test file or is listed as `blocked` with its reason.

6. **Run and heal.** Use this command, with a distinct `<run>` per run (`first`, `final`, `confirm`); it prints the results, writes `<report>/results.json` and `<report>/html`, and exits non-zero when tests fail, which is expected:
   ```sh
   mkdir -p <report> && BASE_URL=<origin> PLAYWRIGHT_HTML_OPEN=never PLAYWRIGHT_HTML_OUTPUT_DIR=<report>/html PLAYWRIGHT_JSON_OUTPUT_FILE=<report>/results.json \
     npx playwright test --project=real-test-desktop --project=real-test-mobile --reporter=list,html,json --output=<report>/artifacts/<run>
   ```
   (POSIX shell; on Windows set the variables the shell's own way.) Do not pipe it into `head` or any command that exits early: the run is cut off before it writes `results.json`. Seed runs are not counted. If the run itself errors (config or load error, no tests found, no `results.json`), show it and stop.
   - No failures: that is the final result; go to step 7.
   - Failures: `mv <report>/results.json <report>/first-run.json`, then `cp -R <out> <report>/pre-heal`, then invoke `playwright-test-healer` (Codex: `playwright_test_healer`) **once** with the standing rules and:
     - Run the tests with `test_run` (`locations: ["<out>"]`), investigate failures with `test_debug`.
     - `specs/real-test-plan.md` is the contract: its `expect:` lines say what each flow must do. Fix only what is wrong in the test: locators, waits (web-first), setup steps. Edit only files under `<out>`, never `seed.spec.ts`.
     - Do not remove, loosen or reorder an assertion, and do not change an expected value so that wrong behaviour passes. If the app contradicts the plan, or the test cannot be fixed with confidence, mark it `fixme` (form below) and keep every step.
     - No `networkidle`, fixed waits, `force: true`, try/catch, `.catch()`, `test.fail`, or route, request and fetch calls.
   - Then `node <skill>/scripts/guard.mjs <out> --baseline <report>/pre-heal --plan specs/real-test-plan.md --json <report>/guard-heal.json` (plus `--require-tag @writes` if writes are allowed). It puts the pre-heal version back when the heal deleted a test, changed or removed any assertion (matcher, arguments, `.not`; not the locator it looks at), edited the seed, a helper or a data file, or broke a rule (an early `return`, an assertion in a loop or condition, `test.fail` and the like). A restored test counts as still failing. A heal that changes the locator text inside an assertion (`getByText('Saved')` to `locator('body')`) is only a warning (`assertion-target-changed`): the guard cannot tell a repair from a weakening, so the report lists every one and you read `diff -ru <report>/pre-heal <out>` for them.
   - Run the command again (`<run>` = `final`). Whatever still fails gets a `fixme` from you instead of a weakened assertion; if you added any, run once more (`<run>` = `confirm`). A test that still fails then (it was unstable) stays as it is and is reported `failed`. Do not heal or loop again.
   - The `fixme` form: `test.fixme(true, '<what the app does instead of what the plan expects>');` as the first statement of the test body, steps kept. If it fails in one project only, take `isMobile` from the test's fixtures and use `test.fixme(isMobile, '<reason>');` (phone) or `test.fixme(!isMobile, '<reason>');` (desktop), so the other project keeps running.

   Done when `<report>/results.json` is the last run, and `<report>/first-run.json` exists if anything failed first.

7. **Report.** Run `node <skill>/scripts/summary.mjs <report>/results.json --plan specs/real-test-plan.md --guard <report>/guard-generate.json [--guard <report>/guard-heal.json] [--first <report>/first-run.json]` and write `<report>/report.md` in the report language from its output, the plan and `diff -ru <report>/pre-heal <out>`. Short: one header, one table, one block per flow that is not `passed`:
   - Header: target, date, production or not, whether `--allow-writes` was used, Playwright version (`npx playwright --version`), the flow counts (`flowTotals`: passed, failed, fixme, blocked, and flaky or skipped if any), one sentence of verdict.
   - Table, one row per flow (`flows`): flow, desktop, phone, status (`passed`, `failed`, `fixme`, `blocked`), note (`healed` where `healed: true`).
   - Per `failed` or `fixme` flow: numbered reproduction steps and the expected result from the plan, what happened instead (`reason`, else `first.error`), screenshot and trace paths (`first.screenshots`, `first.traces`, relative to the project).
   - Per `blocked` flow (`blocked`, plus flows blocked by a login wall or an expired session): why (login wall or expired session, guard rule id, no test generated, step needs a write that is not allowed).
   - Healer changes: one line per changed file from the diff; any guard restore; every entry of `guard.targetChanges` (file, line: the assertion now looks at different locator text) so the reader can check it.
   - Not covered: flows outside the plan (`extra` lists specs in the folder that ran but are not in the plan; they are not counted), steps that stop before a final submit, other browsers, and what a pass does not prove.
   - Where things are: tests in `<out>`, plan `specs/real-test-plan.md`, Playwright HTML report `<report>/html/index.html` (`npx playwright show-report <report>/html`), `<report>/results.json`.
   - Rerun, with no model: `npx playwright test --project=real-test-desktop --project=real-test-mobile` (plain `npx playwright test` when this skill wrote the config); `BASE_URL=<other URL>` points the same tests at another environment. Say that reruns hit whatever `BASE_URL` is, and that with `--allow-writes` the `@writes` tests run only against the origin they were made for.

   Chat: the counts, the `report.md` path, the HTML report path and the rerun command. Never write "the app works".

   Done when `report.md` exists, the sum of `flowTotals` equals the number of scenarios in the approved plan, and every flow that is not `passed` has steps and evidence or says there is none.

## Safety

Standing rules. Put them into every brief to the planner, generator and healer, say in each whether writes are allowed (non-production and `--allow-writes`) or not, and keep to them yourself:
- A write is anything the app sends to a server that creates, changes or deletes data or has an outside effect: send, delete, pay, invite, publish, sign up, submit an order or a form. Without `--allow-writes`, and on a production target whatever the flag says, a scenario stops before the final submit: it may fill the form and assert that the button is enabled, but never clicks it. Interactions that stay in the browser (filters, toggles, local drafts) are not writes.
- `--allow-writes` counts only for a non-production target, and then only with fake data: `name@example.com`, "Test User", obviously fake numbers, the payment provider's test card. With it, final submits are clicked, and a delete on staging cannot be undone. No real personal data, customer records or real cards in a plan, a test or a fixture. If the flag is given for production, ignore it and say so.
- No credentials in a plan, test, brief or chat; never open `.auth/`.
- Tests drive the UI. No `page.route`, HAR or other mocks, no `request` or `fetch` calls, no own browser contexts, no hand-set cookies, tokens or sessions. The guard rejects the common forms of these.
- The plan's `expect:` lines are the assertions. Do not remove or loosen one; a flow that cannot pass becomes `test.fixme` with a reason.

Limits:
- These rules are enforced by the briefs and the guard, not by a network block. A generated test can still click something it should not. On production prefer a read-only account or, better, a staging copy.
- The agents keep `browser_evaluate`, so in-page requests during exploration are limited by the brief only. The main session does not call the `playwright-test` browser tools itself (`browser_route`, `browser_run_code_unsafe`, `browser_evaluate` and the like); only the three agents do. An assertion branch such as `if (isMobile) { ... expect ... }` is rejected on purpose, because it hides the assertion on the other project; use `test.fixme(isMobile, '<reason>')`.
- The guard is a pattern check, not a parser. It catches the usual ways a test hides a failure, bypasses these rules or carries a secret, and compares the matcher and arguments of every assertion against the pre-heal copy. It does not prove a test is good, does not judge which element an assertion looks at, and rejects some harmless code (a label such as "Search tokens" typed into a field counts as a secret).
- One plan, one heal pass, Chromium only, no retries. Not a security, load, accessibility or visual test.
- Snapshots, screenshots and traces in `<report>` can contain the app's data, and traces can contain session cookies; keep the folder out of git and share it with care.
