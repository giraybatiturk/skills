# Browser

## Work without a login
- To read pages, take screenshots, measure UI and run tests, use a local headless CLI browser.
- Use `agent-browser` (it brings its own Chrome for Testing) or `playwright-cli`.
- To install the skill of `playwright-cli`, run `playwright-cli install --skills`.

## Work with a login
- For services that need a login, use the API first. Examples: ad platforms, store consoles, Google, mail.
- If you must use a browser, use the logged-in browser of the user. Use only the own tab group of the agent.
- Close those tabs when the job ends.
- Never touch the open tabs of the user. Never read cookies or passwords.
- If an MCP integration loses its session (for example `needs authentication`), do not ask the user to authenticate again.
- Open the service in the logged-in browser of the user by the same route, with the same tab rules.
- If you give this research to an agent, write this route in its instructions too.
- Fallback: a cloud browser session with a saved profile. The key comes from the password manager of the user.
- Close every session when the job ends.
<!-- Why: Interrupting the browser of the user, or asking for repeated logins, breaks their focus. -->

## Always
- Never type a password. If a login is needed, the user does it.
- Ask the user for verification codes. Never solve a captcha.
- Run long jobs (test rounds, builds, agents) in the background. The user keeps working.
- Go to the user only when you are truly stuck.
- Truly stuck means: a login or MFA, a destructive action that needs approval, or an access permission.

## Claude Code / omp only
- In Claude Code, the logged-in browser route is Claude in Chrome, with the same tab rules.
- Do not use the omp browser relay or a remote debugging port.
- omp is stricter. Do web browsing, tests and screen tests only in the own headless Chromium of omp.
- Never use the Chrome, visible tab, screen, mouse or keyboard of the user.
- If a login is needed, ask for a one-off session recording. The user logs in themselves.
<!-- Why: Automation that takes the visible browser of the user steals their focus. -->
