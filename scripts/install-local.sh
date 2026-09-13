#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd -P)
dest=${1:?Usage: bash scripts/install-local.sh DESTINATION}
names=(real-start real-plan real-audit real-research)
sources=(product/real-start product/real-plan product/real-audit engineering/real-research)
legacy=(real-grill real-feature-gate real-product-audit real-module-audit real-design-audit real-design-rules real-perf-audit)
require_file() {
  if [[ ! -f "$1" ]]; then
    printf 'Incomplete bundle: missing %s. Restore the full checkout before retrying.\n' "$1" >&2
    exit 1
  fi
}
# Preflight the entire bundle and destination before changing any links.
for i in 0 1 2 3; do
  require_file "$repo/skills/${sources[$i]}/SKILL.md"
done
for ref in design-rules orchestration product module design performance security quality motion reporting monetization product-context; do
  require_file "$repo/skills/product/real-audit/references/$ref.md"
done
for ref in discovery feature-gate; do
  require_file "$repo/skills/product/real-plan/references/$ref.md"
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
for i in 0 1 2 3; do
  target="$dest/${names[$i]}"
  [[ ! -L "$target" ]] || unlink "$target"
  ln -s "$repo/skills/${sources[$i]}" "$target"
  test -f "$target/SKILL.md"
done
printf 'Installed and verified all four workflows in %s\n' "$dest"
