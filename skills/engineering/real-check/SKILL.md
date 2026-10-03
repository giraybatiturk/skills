---
name: real-check
description: "Quick automated check of a public URL: site kontrol, siteyi tara, URL check, broken links, console errors, mobile overflow, prospect, client or competitor site report. Rule-based and read-only, about 30 seconds, no code or account access; writes a one-page owner-facing report (HTML + PDF) and, on request, an outreach message draft and a tracking row. Never sends anything. For an in-depth review of your own product use real-audit. (v0.11.0)"
license: MIT
metadata:
  author: Giray Batıtürk
  version: 0.11.0
  source: https://github.com/giraybatiturk/skills
---

# Real check

A fast, deterministic look at one public URL, written for the site's owner. It is often someone else's site: a client, a prospect, a competitor. It reads the home page and its links, nothing else, and says so. `<skill>` below means the directory that contains this `SKILL.md`; resolve it from the client's skill catalog.

Not an audit. `real-check` is a rule-based scan of a public URL with no code or account access; `real-audit` is expert judgment on your own product (repo, running app, screens) with prioritized findings, coverage and validation tasks. A clean `real-check` is not proof the site works.

## Steps

1. **Parse `$ARGUMENTS`.** Required: a URL starting with `http://` or `https://`; otherwise stop and show the usage. Options:
   - `--lang tr|en`: report and message language. Default: the language of the user's conversation (`tr` or `en`; ask once if it is neither).
   - `--brand "Name <email>"`: optional signature for the report footer and the message. No brand by default.
   - `--outreach`: also write a message draft and a tracking row.
   - `--control`: no check, no report; only a tracking row and a neutral message draft for the comparison group of an A/B experiment. Implies `--outreach`.
   - `--out DIR`: output folder. Default `./real-check-reports`; if the user or project has an established outputs convention, use it.

   Done when the URL, language and flags are fixed.

2. **Set up once.** Skip for `--control`. If `<skill>/scripts/node_modules/playwright` is missing (Node 20+ required), run `npm install --prefix <skill>/scripts`, then `npx --prefix <skill>/scripts playwright install chromium`. If installation is not permitted (sandbox, no network, Claude app without a shell), say exactly that and stop; do not fake results.

   Done when Playwright and Chromium are installed, or the blocker has been stated.

3. **Run the check.** `node <skill>/scripts/check.mjs <url> [flags]`. The last stdout line is JSON (exit 0, 3, 4 and 6; exit 2 and 5 write to stderr only). Exit codes:
   - `0` report written (or control row written): continue.
   - `2` usage error: show the message and stop.
   - `3` no findings: say the automated check found nothing worth reporting, and stop. Do not write a message.
   - `4` the site does not open: report the reason and stop.
   - `5` the check could not run: show the tail of stderr and stop.
   - `6` the home page refused the automated visit (likely bot protection): say so, tell the user to verify in their own browser, and stop. Do not write a message.

   Show every entry of `warnings[]` verbatim. If a console finding coexists with a network warning, ask the user to confirm it in their own browser before it is used in a message.

   When called from `real-audit`, run without `--outreach` or `--control` and skip the preview server. Return to the caller: the `findings.json` path (`json` in the JSON line; also written on exit 3), the warnings, and on exit 3, 4 or 6 the status and reason. The screenshots are embedded in the HTML report (`html`), not saved as separate files.

   Done when the exit code is handled, the findings are listed one line each and every warning is shown.

4. **Outreach (only with `--outreach` or `--control`, and only after exit 0).** Write `<slug>-message.md` into the run folder (`slug` and `dir` in the JSON line; the same folder as the report). Top line, as a warning: "Before sending: check consent rules for unsolicited commercial messages in the recipient's jurisdiction (for example GDPR/ePrivacy in the EU, ETK/İYS in Türkiye). Not verified by this skill." Then two drafts in the report language:
   - **LinkedIn:** at most 600 characters.
   - **Email:** subject line and at most 120 words.

   Rules for both:
   - At most 3 findings, one plain sentence each, taken only from the `title` fields in `findings.json`, in the same order. No jargon (console, scrollWidth, Playwright, DOM), no price, discount or urgency.
   - Greeting uses the placeholder `[Name]`; never invent a name.
   - One closing question: would they like the one-page report sent to them. The LinkedIn draft does not mention an attachment; the email says "I can send the one-page report".
   - Signature from `--brand` if given, otherwise `[Your name]`.
   - **Control group (`--control`):** identical opening and closing, no site-specific finding, only a generic line such as "I had a look at your site and a few things stood out".
   - Never send, post, upload or share anything. The user sends.

   Done when `<slug>-message.md` exists, both drafts meet their limits and every finding sentence maps to a `title`.

5. **Preview and hand over.** With a report (exit 0, not `--control`): serve the run folder on a free, OS-assigned port bound to `127.0.0.1` (for example `python3 -m http.server 0 --bind 127.0.0.1` in the background), check with `curl` that the served `<title>` is the report's, and say how to stop the server. Give clickable links: the HTML report from the preview server, and the PDF, the message and `outreach.csv` as absolute `file://` URLs. With `--control` there is no report: skip the preview and link the message and CSV only. Report each finding on one line, then any warnings. The CSV row has `status=draft`; the user updates it after sending.

   Done when every link opens and the findings and warnings are listed.

## Boundaries

- Home page and the same-site links on it only (first 50, GET, redirects followed by hand and only within the site). No form submission, checkout or login. Every HTTP request other than GET, HEAD and OPTIONS is aborted and every WebSocket is closed; console errors caused by that guard are dropped and reported as a warning.
- Rule-based, not a quality score. A third-party network failure, or a link that answers 401, 403, 429 or 503, is a warning, not a finding.
- The browser identifies itself as automated (`real-check/0.11` in the user agent). The check does not read `robots.txt`; it loads the home page twice (desktop and phone width) and sends up to 50 GET requests to the same host.

## Experiment

When the user runs an outreach A/B, read `outreach.csv`. If the report and control groups differ in size by 2 or more, say so in one line. The decision rule belongs to the user; do not set one.
