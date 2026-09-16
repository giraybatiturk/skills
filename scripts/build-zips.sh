#!/usr/bin/env bash
# Build one upload-ready zip per skill for claude.ai / Claude desktop (Customize > Skills > Upload a skill).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/dist"
rm -rf "$out"; mkdir -p "$out"
for rel in $(jq -r '.skills[]' "$root/.claude-plugin/plugin.json"); do
  dir="$root/$rel"; name="$(basename "$dir")"
  (cd "$(dirname "$dir")" && zip -qr "$out/$name.zip" "$name" -x '*.DS_Store')
  echo "$out/$name.zip"
done
