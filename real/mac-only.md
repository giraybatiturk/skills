# Mac only

These rules apply on macOS only.
`taskpolicy` does not exist on Linux or a remote box. There, only that machine's own load rules apply.

- Throttle all heavy local work: builds, tests, renders, conversions (`xcodebuild`, `swift build`, `npm run build`, test suites, `ffmpeg`, Playwright).
- Start them with `taskpolicy -c background`.
- Keep parallelism at 2: `xcodebuild -jobs 2`, `jest` or `vitest` with `--maxWorkers=2`, `ffmpeg -threads 2`, Playwright `--workers=2`.
- That is the ceiling unless the user asks for speed.
- One build at a time.
- Before starting, run `pgrep -fl "xcodebuild|swift-build|swift-frontend"`.
- If another session is building, wait for it. Do not start a second build.
- At most 3 agents in parallel. Discovery and scanning on the fastest tier. Four or more only on the user's explicit request (see `models-and-orchestration.md`).
- When the job ends, close background processes: dev server, `http.server`, watchers, simulator.
- At session end, check with `pgrep`.
- Project-specific load rules are kept in the private overlay.
<!-- Why: Several heavy jobs at once overloaded the machine until it was barely usable. -->
