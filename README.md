# Skills for real AI product leads

Six connected workflows for deciding what to build, proving what exists, and improving products with evidence.

## The six workflows

| Skill | Use it for |
|---|---|
| `/real-start` | Route an ambiguous or mixed request |
| `/real-brainstorm` | Generate ideas or stress-test one: research, 5 Whys debate, separate judge, one recommendation |
| `/real-plan` | Shape and approve a feature, change, or decision before code |
| `/real-audit` | Improve a product, module, screen, flow, or measured web performance |
| `/real-check` | Quick automated check of any public URL: one-page owner-facing report, optional outreach draft |
| `/real-research` | Resolve current external facts from primary sources |

`real-check` and `real-audit` are different jobs. `real-check` takes any public URL with no code or account access, typically finishes in about 30 seconds, is rule-based and deterministic, and writes a one-page report for the site's owner; the site is often someone else's (client, prospect, competitor). `real-audit` is expert judgment on your own product in depth (repo, running app, screens) with prioritized findings, coverage and validation tasks. `real-audit` runs `real-check` first when its scope includes the product's public web surface.

You do not have to type a command. Their descriptions are available to the model, so a request such as “What should we improve in this product?” can invoke `real-audit` automatically. Direct commands remain available when you want a specific workflow.

`real-audit` progressively loads Product, Module, Design, Monetization, Security, Quality, and Performance modes. A whole-product audit assesses applicability across value, UX/design, security/privacy, quality/reliability and performance; a narrow task stays narrow. `real-plan` contains discovery and the five-heading feature gate. Baseline design rules are supporting material inside the audit, so they do not add another command.

Automatic selection is client- and context-dependent, not guaranteed. Confirm a successful instruction load in the trace when testing routing. Earlier behavioral evaluation artifacts were removed and are no longer independently inspectable in this repository. Current reproducible checks and their limits are listed in [verification status](docs/real-hardening-status.md). New instruction revisions still need behavioral retesting.

## Orchestration

Small reversible work stays with one agent. The workflows split work when it is externally visible, sensitive, cross-repository, dependent on live external facts, larger than 10 files, or explicitly requested as orchestration.

Triggered work uses at least two independent perspectives and an adversarial verifier. Models are chosen by capability rather than pinned versions:

| Work | Codex preference | Claude-compatible preference |
|---|---|---|
| Product architecture and synthesis | Astra | highest product/architecture tier, including Fable when offered |
| Adversarial verification | Astra | Opus |
| Broad implementation | Sol | Sonnet |
| UI/product implementation | Terra | Sonnet |
| Mechanical discovery | Luna or Spark | Haiku |

If a family is unavailable, use the nearest capability tier. The verifier cannot be weaker than the strongest producer it checks.

## Install

### Claude Code plugin

```text
/plugin marketplace add giraybatiturk/skills
/plugin install giraybatiturk-skills@giraybatiturk
```

Plugin commands are namespaced, for example `/giraybatiturk-skills:real-audit`.

### Claude Code symlinks

Use this route for short commands and immediate local edits. Do not enable the plugin at the same time.

```bash
# First clone the repository if no local checkout exists.
git clone https://github.com/giraybatiturk/skills.git "$HOME/Developer/skills"
bash "$HOME/Developer/skills/scripts/install-local.sh" "$HOME/.claude/skills"
```

If the checkout already exists, skip cloning. The installer validates the whole bundle before changing links, supports repeated runs, and stops on copied directories or foreign links. Move conflicts to a backup outside the skills directory and retry. For local Codex installation, run the same script with `"$HOME/.agents/skills"`.

### Claude app (claude.ai and Claude desktop)

Each skill uploads as its own zip; the app does not accept a multi-skill bundle. Download the six zips from the [latest release](https://github.com/giraybatiturk/skills/releases/latest), then in the app open Customize > Skills > + > Upload a skill and upload them one by one. Upload all six; `real-plan` and `real-start` expect `real-audit` next to them.

To build the zips from a checkout instead:

```bash
bash scripts/build-zips.sh
```

Each description ends with a version stamp such as `(v0.8.0)`, so the app's skill list shows which release is installed. On a new release, upload the new zip again; a skill with the same name is updated in place.

### Codex

```bash
npx skills@latest add giraybatiturk/skills -g -a codex -s '*' -y
```

Open a new session after installation. The public list should contain exactly `real-start`, `real-brainstorm`, `real-plan`, `real-audit`, `real-check`, and `real-research`.

The supported installation is the complete six-skill bundle. Plan depends on Audit references; installing Plan alone is unsupported and produces an explicit missing-dependency message. Existing copied installations require migration using the conflict instructions above.

## Dependencies

`real-check` needs Node 20+ and downloads Chromium (through Playwright) on first run. Where installing is not permitted, it stops and says so instead of faking a result. The other workflows are instructions only.

To run the `real-check` local test from a checkout: `node scripts/test-real-check.mjs` (Node standard library only; needs Playwright and Chromium installed in `skills/engineering/real-check/scripts`).

## Natural-language routing

Intended routes below depend on client selection; use the explicit command when routing must be deterministic.

- “What feature should we build next in this app?” → `real-brainstorm`: Quick or Deep; Deep adds competitor and pricing research, a 5 Whys debate and a separate judge.
- “Build medication reminders” → `real-plan`: User story, Analysis, Backend scope, Frontend scope, and Connection before code.
- “What should we improve next in this product?” → `real-audit` Product mode.
- “This screen feels crowded” → `real-audit` Design mode, project `DESIGN.md` before the baseline.
- “Check the latest App Store rule” → `real-research`, primary sources.
- “Check https://example.com for broken links before I email the owner” → `real-check`: automated scan of the public URL, one-page report, optional message draft that is never sent.
- “Audit our checkout flow” → `real-audit`: your own product in depth, evidence from the running app and code.
- “Is this animation smooth?” → `real-audit` Design with Motion, runtime evidence required.

## Migration from 0.7

| Previous command | New route |
|---|---|
| `/real-grill` | `/real-plan` discovery |
| `/real-feature-gate` | `/real-plan` feature gate |
| `/real-product-audit` | `/real-audit` Product |
| `/real-module-audit` | `/real-audit` Module |
| `/real-design-audit` | `/real-audit` Design |
| `/real-perf-audit` | `/real-audit` Performance |
| `real-design-rules` | loaded by `real-plan` and `real-audit` for UI work |

Old commands are intentionally absent from discovery so the menu stays small. `real-start` knows the mapping and routes old terminology to the new workflows.

## Changelog

- **0.11.0** (2026-10-03): Added `real-check`: a quick, rule-based, read-only check of any public URL that writes a plain-language one-page report (HTML + PDF) for the site's owner. Checks that the page opens, browser console errors, broken links on the home page, and the phone layout at 375 px (horizontal overflow, or a missing viewport setting). Optional `--outreach` makes the script write a tracking row (also for runs that end without a report) and the skill, that is the agent, write a message draft (at most three findings, no jargon, nothing is sent); `--control` makes no request: the script writes only the tracking row and creates the run folder, and the agent writes a neutral draft for an A/B comparison group. False positives are filtered: a failed load from another registrable domain, including an HTTP error, is a warning; only 404, 410, 500, 502 and 504 count as broken links (redirects are followed only within the site); links that look like actions (log out, delete, cancel, cart, `confirm` or `...token` query parameters) are not requested and are reported as not checked, in English, Turkish, German, French, Spanish, Italian, Portuguese and Dutch (mostly stems, so nouns match too; the non-English words come from general knowledge, not from measured sites; a few short words match only as whole words and some stems only at the start of a word, which still skips everyday uses such as `/donde-salir`), and because keywords match anywhere in the address an ordinary page such as `/cancellation-policy` is skipped and listed too; a refused home page (401, 403, 429, 503, Cloudflare challenge) is reported as blocked rather than as a finding; every write request is blocked (a page that submits a form as it loads ends the check with exit 4 and a reason that names the blocked write), and so is every request the page sends straight to a private or local address (literal addresses only, no DNS lookup; a redirect to one is detected, not prevented). Console errors that follow a blocked request are not counted as findings: a failed load of the same URL or a generic network error within about 2 seconds, and WebSocket errors after a closed WebSocket (no time window). They are reported as possibly caused by the block and kept in `findings.json`. When the home page has more than 50 links to check, a warning says how many were found and that only the first 50 were checked. Boundary: `real-check` is for any public URL with no code access; `real-audit` stays the in-depth review of your own product, and `real-audit` now runs `real-check` first as automated evidence when its scope includes a public web surface. `real-start` routes to it; the `real-audit` and `real-start` stamps move to 0.11.0 because their behavior changed. A local test script, `scripts/test-real-check.mjs`, runs the helpers and the CLI against local fixture servers; it is not part of the skill zip. Needs Node 20+ and downloads Chromium on first run.
- **0.10.0** (2026-09-29): Added `real-brainstorm`: Quick/Deep depth, independent generators (mind map, SCAMPER, reverse brainstorming, role storming), market card with competitor, precedent, willingness-to-pay and revenue-range evidence, 5 Whys debate, pairwise judge blind to idea origin, three user checkpoints and a local report. Reads Real Audit monetization/reporting/orchestration and Real Research rules read-only. `real-start` routes to it; `real-plan` description points idea generation there.
- **0.8.0** (2026-09-13): Consolidated nine entries into four workflows; added automatic natural-language routing, progressive audit modes, capability-based orchestration, and a four-item install path.
- **0.7.0** (2026-09-13): Added the product audit.
- **0.6.0** (2026-09-10): Restored the interactive start router.
- **0.5.0** (2026-09-09): Reduced the original 19-skill set to seven focused workflows.
