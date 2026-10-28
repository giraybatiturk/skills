#!/usr/bin/env bash
set -euo pipefail
# Note: this script only links the seven workflows. It never writes CLAUDE.md or AGENTS.md.
# For the optional real.md working rules see scripts/install-real-md.sh (backs up first).
repo=$(cd "$(dirname "$0")/.." && pwd -P)
dest=${1:?Usage: bash scripts/install-local.sh DESTINATION}
names=(real-start real-brainstorm real-plan real-audit real-check real-test real-research real-measure)
sources=(product/real-start product/real-brainstorm product/real-plan product/real-audit engineering/real-check engineering/real-test engineering/real-research product/real-measure)
legacy=(real-grill real-feature-gate real-product-audit real-module-audit real-design-audit real-design-rules real-perf-audit)
require_file() {
  if [[ ! -f "$1" ]]; then
    printf 'Incomplete bundle: missing %s. Restore the full checkout before retrying.\n' "$1" >&2
    exit 1
  fi
}
# Preflight the entire bundle and destination before changing any links.
for i in "${!sources[@]}"; do
  require_file "$repo/skills/${sources[$i]}/SKILL.md"
done
for file in check.mjs package.json; do
  require_file "$repo/skills/engineering/real-check/scripts/$file"
done
for file in scripts/guard.mjs scripts/summary.mjs scripts/visual.mjs assets/fixtures.ts; do
  require_file "$repo/skills/engineering/real-test/$file"
done
for ref in design-rules orchestration product module design performance security quality motion reporting monetization product-context deliverable live-audit; do
  require_file "$repo/skills/product/real-audit/references/$ref.md"
done
for ref in discovery feature-gate; do
  require_file "$repo/skills/product/real-plan/references/$ref.md"
done
for file in scripts/stats.mjs references/metrics.md references/sources.md; do
  require_file "$repo/skills/product/real-measure/$file"
done
for ref in techniques debate market; do
  require_file "$repo/skills/product/real-brainstorm/references/$ref.md"
done
for name in "${names[@]}" "${legacy[@]}"; do
  target="$dest/$name"
  if [[ -L "$target" ]]; then
    case "$(readlink "$target")" in "$repo/skills/"*) ;; *)
      printf 'Foreign link: %s. Move it to a backup outside the skills directory before retrying.\n' "$target" >&2; exit 1 ;; esac
  elif [[ -e "$target" ]]; then
    printf 'Existing file/directory: %s. Move it to a backup outside the skills directory before retrying.\n' "$target" >&2
    exit 1
  fi
done
mkdir -p "$dest"
for name in "${legacy[@]}"; do
  [[ ! -L "$dest/$name" ]] || unlink "$dest/$name"
done
for i in "${!names[@]}"; do
  target="$dest/${names[$i]}"
  [[ ! -L "$target" ]] || unlink "$target"
  ln -s "$repo/skills/${sources[$i]}" "$target"
  test -f "$target/SKILL.md"
done
printf 'Installed and verified all eight workflows in %s\n' "$dest"
