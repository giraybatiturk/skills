# Skills for real AI product leads

Four connected workflows for deciding what to build, proving what exists, and improving products with evidence.

## The four workflows

| Skill | Use it for |
|---|---|
| `/real-start` | Route an ambiguous or mixed request |
| `/real-plan` | Shape and approve a feature, change, or decision before code |
| `/real-audit` | Improve a product, module, screen, flow, or measured web performance |
| `/real-research` | Resolve current external facts from primary sources |

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

### Codex

```bash
npx skills@latest add giraybatiturk/skills -g -a codex -s '*' -y
```

Open a new session after installation. The public list should contain exactly `real-start`, `real-plan`, `real-audit`, and `real-research`.

The supported installation is the complete four-skill bundle. Plan depends on Audit references; installing Plan alone is unsupported and produces an explicit missing-dependency message. Existing copied installations require migration using the conflict instructions above.

## Natural-language routing

Intended routes below depend on client selection; use the explicit command when routing must be deterministic.

- “Build medication reminders” → `real-plan`: User story, Analysis, Backend scope, Frontend scope, and Connection before code.
- “What should Dosehue improve next?” → `real-audit` Product mode.
- “This screen feels crowded” → `real-audit` Design mode, project `DESIGN.md` before the baseline.
- “Check the latest App Store rule” → `real-research`, primary sources.
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

Old commands are intentionally absent from discovery so the menu remains four items. `real-start` knows the mapping and routes old terminology to the new workflows.

## Changelog

- **0.8.0** (2026-09-13): Consolidated nine entries into four workflows; added automatic natural-language routing, progressive audit modes, capability-based orchestration, and a four-item install path.
- **0.7.0** (2026-09-13): Added the product audit.
- **0.6.0** (2026-09-10): Restored the interactive start router.
- **0.5.0** (2026-09-09): Reduced the original 19-skill set to seven focused workflows.
