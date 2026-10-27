# Browser

## Work without a login
- For reading pages, screenshots, UI measurement and tests, use a local headless CLI browser.
- Use `agent-browser` (it brings its own Chrome for Testing) or `playwright-cli` (install its skill with `playwright-cli install --skills`).

## Work with a login
- For services that need a login (ad platforms, store consoles, Google, mail), use the API first.
- If a browser is unavoidable, use the user's logged-in browser through the agent's own tab group only.
- Close those tabs when the job ends.
- Never touch the user's open tabs. Never read cookies or passwords.
- If an MCP integration loses its session (for example `needs authentication`), do not make the user re-authenticate.
- Open the service in the user's logged-in browser by the same route, with the same tab rules.
- Handing that research to an agent? Write this route into its instructions too.
- Fallback: a cloud browser session with a saved profile. The key comes from the user's password manager. Close every session when the job ends.
<!-- Why: Interrupting the user's own browser or asking for repeated logins breaks their focus. -->

## Always
- Never type a password. If a login is needed, the user does it.
- Ask the user for verification codes. Never solve a captcha.
- Run long jobs (test rounds, builds, agents) in the background while the user keeps working.
- Go to the user only when truly stuck: login or MFA, a destructive action that needs approval, an access permission.

## Claude Code / omp only
- In Claude Code the logged-in browser route is Claude in Chrome, with the same tab rules.
- Do not use the omp browser relay or a remote debugging port.
- omp is stricter: do web browsing, tests and screen checks only in omp's own headless Chromium.
- Never use the user's Chrome, visible tab, screen, mouse or keyboard.
- If a login is needed, ask for a one-off session recording (the user logs in themselves).
<!-- Why: Automation that grabs the user's visible browser steals focus from what they are doing. -->
