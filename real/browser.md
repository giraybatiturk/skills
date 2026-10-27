# Browser

## Work without a login
- Page reading, screenshots, UI measurement and tests: use a local headless CLI browser. `agent-browser` (it brings its own Chrome for Testing) or `playwright-cli` (install its skill with `playwright-cli install --skills`).

## Work with a login
- For services that need a login (ad platforms, store consoles, Google, mail), use the API first.
- If a browser is unavoidable, use the user's logged-in browser only through the agent's own tab group. Close those tabs when the job ends. Never touch the user's open tabs. Never read cookies or passwords.
- If an MCP integration loses its session (for example `needs authentication`), do not make the user run a re-authentication command. Open the service in the user's logged-in browser by the same route and with the same tab rules. When you hand that research to an agent, write this route into its instructions too.
- Fallback: a cloud browser session with a saved profile (the key comes from the user's password manager). Close every session when the job ends.

## Always
- Never type a password; if a login is needed, the user does it. Ask the user for verification codes. Never solve a captcha.
- Long jobs (test rounds, builds, agents) run in the background while the user keeps using the computer. Go to the user only when truly stuck: login or MFA, a destructive action that needs approval, an access permission.

## Claude Code / omp only
- In Claude Code the logged-in browser route above is Claude in Chrome, with the same tab rules.
- Do not use the omp browser relay or a remote debugging port.
- Stricter in omp: web browsing, tests and screen checks are always done in omp's own headless Chromium. The user's Chrome, visible tab, screen, mouse and keyboard are never used. If a login is needed, ask for a one-off session recording (the user logs in themselves).
