# Mac only

These rules apply on macOS only.
`taskpolicy` does not exist on Linux or a remote box. On those machines, use only the load rules of that machine.

- Throttle all heavy local work: builds, tests, renders and conversions.
- Examples: `xcodebuild`, `swift build`, `npm run build`, test suites, `ffmpeg`, Playwright.
- Start them with `taskpolicy -c background`.
- Keep parallelism at 2: `xcodebuild -jobs 2`, `jest` or `vitest` with `--maxWorkers=2`, `ffmpeg -threads 2`, Playwright `--workers=2`.
- This is the maximum, unless the user asks for speed.
- Run one build at a time.
- Before you start, run `pgrep -fl "xcodebuild|swift-build|swift-frontend"`.
- If another session builds, wait for it. Do not start a second build.
- Run at most 3 agents in parallel. Run discovery and scanning on the fastest tier.
- Run 4 or more agents only when the user asks (see `models-and-orchestration.md`).
- When the job ends, close background processes: dev server, `http.server`, watchers, simulator.
- At the end of the session, run `pgrep` to find processes that remain.
- Keep project-specific load rules in the private overlay.
<!-- Why: Many heavy jobs at one time overloaded the machine. -->
