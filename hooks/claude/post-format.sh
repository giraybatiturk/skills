#!/bin/sh
# real-hooks-managed
# PostToolUse hook. Matcher for Claude Code: Edit|MultiEdit|Write
# It runs on the edited file only. It does two quick things:
#   1. Format. Use the command in REAL_FORMAT_CMD or format.cmd (the text {file} is the path),
#      else the local node_modules/.bin/prettier when it exists.
#   2. Syntax check. Use REAL_CHECK_CMD or check.cmd ({file} is the path).
#      Defaults: node --check for .js/.mjs/.cjs, python3 -m py_compile for .py, sh -n for .sh.
#      A typecheck of one TypeScript file is not reliable without the project config. Set check.cmd if you want it.
# The hook stays silent when all is fine. A failed check exits 2. Claude sees the stderr text.
# The Stop gate runs the full typecheck, lint and tests. Bash edits are covered there.
# Set REAL_POST_FORMAT=0 to turn this hook off. Codex does not give the file path of an edit, so this hook is not for Codex.

. "$(dirname "$0")/lib.sh"
set -f

[ "${REAL_POST_FORMAT:-1}" = 0 ] && exit 0
file=$(rh_field file_path)
[ -n "$file" ] && [ -f "$file" ] || exit 0
root=$(rh_root)

fmt=$(rh_cfg format.cmd)
chk=$(rh_cfg check.cmd)

case $file in
  *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.json|*.css|*.scss|*.md|*.mdx|*.yml|*.yaml|*.html) fmt_ok=yes ;;
  *) fmt_ok=no ;;
esac

if [ -n "$fmt" ]; then
  ( cd "$root" && sh -c "$(printf '%s' "$fmt" | sed "s|{file}|'$file'|g")" ) >/dev/null 2>&1
elif [ "$fmt_ok" = yes ] && [ -x "$root/node_modules/.bin/prettier" ]; then
  ( cd "$root" && ./node_modules/.bin/prettier --write --log-level silent "$file" ) >/dev/null 2>&1
fi

if [ -z "$chk" ]; then
  case $file in
    *.js|*.mjs|*.cjs) command -v node >/dev/null 2>&1 && chk="node --check {file}" ;;
    *.py) command -v python3 >/dev/null 2>&1 && chk="python3 -m py_compile {file}" ;;
    *.sh) chk="sh -n {file}" ;;
  esac
fi
if [ -n "$chk" ]; then
  out=$( cd "$root" && sh -c "$(printf '%s' "$chk" | sed "s|{file}|'$file'|g")" 2>&1 )
  if [ $? -ne 0 ]; then
    printf 'real: the syntax check failed for %s:\n%s\n' "$file" "$(printf '%s' "$out" | head -n 15)" >&2
    exit 2
  fi
fi
exit 0
