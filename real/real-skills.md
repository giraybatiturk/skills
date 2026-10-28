# Real skills

The README describes the connected workflows. They help you decide what to build, prove what exists, measure what shipped, and improve a product.

## The skills
- `real-start`: route an ambiguous or mixed request.
- `real-brainstorm`: generate ideas or stress-test one. Steps: research, 5 Whys debate, separate judge, one recommendation.
- `real-plan`: shape and approve a feature, change or decision before code. It has discovery and the five-heading gate.
- `real-audit`: improve a product, module, screen, flow or web performance with evidence. It holds the design baseline and the orchestration references.
- `real-check`: quick automated scan of a public URL, with a one-page report for the user. It is not a done check for your own work.
- `real-test`: Playwright tests for the key user flows of your own web app. Steps: plan, generate, run, heal once, report.
- `real-research`: resolve current external facts from primary sources.
- `real-measure`: after release, judge with live data if a change hit its goal. It is read-only.

## Routing
- For work that spans skills, use this order:
  1. Research unresolved external facts.
  2. Brainstorm, if no candidate exists.
  3. Plan.
  4. Implement, only after approval.
  5. Audit.
  6. Test the key flows.
  7. After release, measure the result with `real-measure`.
- Skip each stage whose evidence is already settled.
- Start product work with `real-start`. It picks the real skill that fits the job.
<!-- Why: One entry point stops product work from starting in the wrong workflow. -->

## Verify before you say done
- Proof of your own work is the contract report, `real-test` and, for a UI change, `real-shot`.
- The report lists Claimed Done and Verified apart. Each Verified item has evidence.
- Do not use `real-check` as this proof. It scans a public URL. A clean scan does not show that your change works.
- Run `real-check` only when the work covers a public site. Then run it in addition to the proof above.
<!-- Why: A rule text named `real-check` as the step before "done". It only scans a public URL, so it gives false trust. -->

## Install
- Claude Code symlinks: `bash <checkout>/scripts/install-local.sh ~/.claude/skills`. It validates the bundle first. You can run it again.
- Codex: `npx skills@1.7.4 add <this-repo> -g -a codex -s '*' -y`. Then open a new session.
- Local Codex install: run the same script with `~/.agents/skills`.
- Install the complete bundle. Do not install a part of it. `real-plan` depends on `real-audit` references.
- The README also describes the plugin route and the Claude app zips.
