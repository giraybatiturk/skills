# Real skills

The README describes seven connected workflows: decide what to build, prove what exists, and improve a product with evidence.

## The seven skills
- `real-start`: route an ambiguous or mixed request.
- `real-brainstorm`: generate ideas or stress-test one. Steps: research, 5 Whys debate, separate judge, one recommendation.
- `real-plan`: shape and approve a feature, change or decision before code. It has discovery and the five-heading gate.
- `real-audit`: improve a product, module, screen, flow or web performance with evidence. It holds the design baseline and the orchestration references.
- `real-check`: quick automated test of a public URL, with a one-page report for the user.
- `real-test`: Playwright tests for the key user flows of your own web app. Steps: plan, generate, run, heal once, report.
- `real-research`: resolve current external facts from primary sources.

## Routing
- For work that spans skills, use this order:
  1. Research unresolved external facts.
  2. Brainstorm, if no candidate exists.
  3. Plan.
  4. Implement, only after approval.
  5. Audit.
  6. Test the key flows.
- Skip each stage whose evidence is already settled.
- Start product work with `real-start`. It picks the real skill that fits the job.
<!-- Why: One entry point stops product work from starting in the wrong workflow. -->

## Install
- Claude Code symlinks: `bash <checkout>/scripts/install-local.sh ~/.claude/skills`. It validates the bundle first. You can run it again.
- Codex: `npx skills@1.7.4 add <this-repo> -g -a codex -s '*' -y`. Then open a new session.
- Local Codex install: run the same script with `~/.agents/skills`.
- Install the complete seven-skill bundle. `real-plan` depends on `real-audit` references.
- The README also describes the plugin route and the Claude app zips.
