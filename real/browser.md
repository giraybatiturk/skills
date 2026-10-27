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
- To open a file or a page for the user, follow the section "Open on request" in `real/output.md`.
- Never type a password. If a login is needed, the user does it.
- Ask the user for verification codes. Never solve a captcha.
- Run long jobs (test rounds, builds, agents) in the background. The user keeps working.
- Go to the user only when you are truly stuck.
- Truly stuck means: a login or MFA, a destructive action that needs approval, or an access permission.

## Wait for a human step
- A human step is, for example, a login, a code, a download, an upload or an action on a phone.
- After you ask for a human step, do not end the turn. Do not wait for the user to write "done".
- Wait in the background for a sign that the step is complete. Examples: an element on the page, the page title, a file, the state of a pull request.
- Check the sign every few seconds. Continue when it appears.
- For a login, wait for an element that shows the user is signed in. Never read cookies or passwords.
- While you wait, do other work that does not depend on the step.
- If 10 minutes pass with no sign, end the turn with `STATE: blocked - <what you need from the user>`. For a pull request merge, wait 30 minutes.
<!-- Why: The user did the step and then had to write "done". The agent was idle or had ended the turn. -->

## Claude Code / omp only
- In Claude Code, the logged-in browser route is Claude in Chrome, with the same tab rules.
- Do not use the omp browser relay or a remote debugging port.
- omp is stricter. Do web browsing, tests and screen tests only in the own headless Chromium of omp.
- Never use the Chrome, visible tab, screen, mouse or keyboard of the user.
- If a login is needed, ask for a one-off session recording. The user logs in themselves.
<!-- Why: Automation that takes the visible browser of the user steals their focus. -->
