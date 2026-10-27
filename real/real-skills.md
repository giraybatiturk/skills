# Real skills

Seven connected workflows from the README: decide what to build, prove what exists, improve a product with evidence.

## The seven skills
- `real-start`: route an ambiguous or mixed request.
- `real-brainstorm`: generate ideas or stress-test one (research, 5 Whys debate, separate judge, one recommendation).
- `real-plan`: shape and approve a feature, change or decision before code (discovery plus the five-heading gate).
- `real-audit`: improve a product, module, screen, flow or web performance with evidence. It holds the design baseline and orchestration references.
- `real-check`: quick automated check of a public URL, with a one-page report for the owner.
- `real-test`: Playwright tests for the key user flows of your own web app (plan, generate, run, heal once, report).
- `real-research`: resolve current external facts from primary sources.

## Routing
- Order across skills: research unresolved external facts, brainstorm if no candidate exists, plan, implement only after approval, audit, then test the key flows.
- Skip stages whose evidence is already settled.
- Product work starts by loading `real-start`. It picks the real skill that fits the job.
<!-- Why: One entry point stops product work from starting in the wrong workflow. -->

## Install
- Claude Code symlinks: `bash <checkout>/scripts/install-local.sh ~/.claude/skills`. It validates the bundle first and can be re-run.
- Codex: `npx skills@1.7.4 add <this-repo> -g -a codex -s '*' -y`, then open a new session.
- Local Codex install: run the same script with `~/.agents/skills`.
- Install the complete seven-skill bundle. `real-plan` depends on `real-audit` references.
- The README also covers the plugin route and the Claude app zips.
