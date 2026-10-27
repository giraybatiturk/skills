# Mac only

These rules apply on macOS only. `taskpolicy` does not exist on Linux or a remote box; there, only that machine's own memory and load rules apply.

- Heavy local work is always throttled: builds, tests, renders and conversions (`xcodebuild`, `swift build`, `npm run build`, test suites, `ffmpeg`, Playwright) start with `taskpolicy -c background`, and parallelism stays at 2: `xcodebuild -jobs 2`, `jest` or `vitest` with `--maxWorkers=2`, `ffmpeg -threads 2`, Playwright `--workers=2`. This is the ceiling unless the user asks for speed.
- One build at a time. Before starting, run `pgrep -fl "xcodebuild|swift-build|swift-frontend"`; if another session is building, wait for it to finish (monitor it) and do not start a second build.
- At most 3 agents in parallel; discovery and scanning on the fastest tier. Four or more only at the user's explicit request (see `models-and-orchestration.md`).
- When the job ends, close background processes: dev server, `http.server`, watchers, simulator. At session end, check with `pgrep`.
- Project-specific load rules (for example CI gates that are not run locally) are kept in the private overlay.
