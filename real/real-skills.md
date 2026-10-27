# Real skills

Seven connected workflows from the README: deciding what to build, proving what exists, improving a product with evidence.

## The seven skills
- `real-start`: route an ambiguous or mixed request.
- `real-brainstorm`: generate ideas or stress-test one (research, 5 Whys debate, separate judge, one recommendation).
- `real-plan`: shape and approve a feature, change or decision before code (discovery plus the five-heading feature gate).
- `real-audit`: improve a product, module, screen, flow or measured web performance, with evidence-backed findings; holds the design baseline and orchestration references.
- `real-check`: quick automated check of any public URL, with a one-page owner-facing report.
- `real-test`: Playwright tests for the key user flows of your own web app (plan, generate, run, heal once, report).
- `real-research`: resolve current external facts from primary sources.

## Routing
- Order for work that spans skills: research unresolved external facts, brainstorm when no candidate exists, plan, implement only after approval, audit, then test the key flows. Skip stages whose evidence is already settled.
- Product work starts by loading `real-start`, which then picks the real skill that fits the job. (NEW, 27 Oct 2026)

## Install
- Claude Code symlinks, from a checkout of this repo: `bash <checkout>/scripts/install-local.sh ~/.claude/skills`. The installer validates the bundle first and can be re-run.
- Codex: `npx skills@1.7.4 add <this-repo> -g -a codex -s '*' -y`, then open a new session. For a local Codex install, run the same script with `~/.agents/skills`.
- Install the complete seven-skill bundle; `real-plan` depends on `real-audit` references. The README also covers the plugin route and the Claude app zips.
