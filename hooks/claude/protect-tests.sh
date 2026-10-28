#!/bin/sh
# real-hooks-managed
# PreToolUse hook. Matcher for Claude Code: Edit|MultiEdit|Write. For Codex: apply_patch.
# It guards test files against changes that weaken them. It blocks (exit 2) when an edit of a test file:
#   1. removes tests (fewer test declarations than before),
#   2. adds a skip or only marker: .skip, .only, .todo, xit, xtest, xdescribe, fit, fdescribe,
#      pytest.mark.skip, pytest.skip, t.Skip, @Disabled, @unittest.skip,
#   3. adds a trivial assertion: expect(true).toBe(true), assert True, assert 1 == 1, assert.ok(true) and the like.
# test.fixme is allowed. real-test uses it with a reason for flows that fail.
# A rename is a Write to a new path, so there is no old file to compare. It does not cause noise.
# Test files: *.test.*, *.spec.*, *_test.go, *_test.py, test_*.py, and files under tests/, __tests__/, e2e/, cypress/.
# Bypass: the user sets REAL_ALLOW_TEST_EDIT=1 before the agent starts.
# MultiEdit needs jq. Without jq the hook skips MultiEdit.

. "$(dirname "$0")/lib.sh"
set -f

[ "${REAL_ALLOW_TEST_EDIT:-}" = 1 ] && exit 0
tool=$(rh_field tool_name)

is_test_path() {
  case $1 in
    *.test.*|*.spec.*|*_test.go|*_test.py|test_*.py|*/test_*.py|*/__tests__/*|*/tests/*|*/e2e/*|*/cypress/*|tests/*|__tests__/*|e2e/*|cypress/*) return 0 ;;
  esac
  return 1
}

RE_TEST='(^|[^A-Za-z0-9_])(it|test|specify)(\.(each|concurrent))?\(|(^|[^A-Za-z0-9_])test\.fixme\([`"'"'"']|def test_|func Test[A-Z_]'
RE_SKIP='(^|[^A-Za-z0-9_])(it|test|describe)\.(skip|only|todo)([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_])(xit|xtest|xdescribe|fit|fdescribe)\(|pytest\.mark\.(skip|xfail)|pytest\.skip\(|t\.Skip\(|@Disabled|@unittest\.skip'
RE_TRIVIAL='expect\((true|false|1)\)\.(toBe\((true|false|1)\)|toBeTruthy\(\)|toEqual\((true|false|1)\))|assert[[:space:]]+True([[:space:]]|,|$)|assert[[:space:]]+1[[:space:]]*==[[:space:]]*1|assert\.ok\(true\)|assert\(true\)|assertTrue\(true\)|assertTrue\(True\)'

count() { printf '%s' "$2" | grep -oE "$1" | wc -l | tr -d ' '; }

check() { # $1 = path, $2 = old text, $3 = new text
  oc=$(count "$RE_TEST" "$2"); nc=$(count "$RE_TEST" "$3")
  if [ "$oc" -gt "$nc" ]; then
    rh_block "The edit of $1 removes $((oc - nc)) test(s). Do not remove tests. Fix the code or the test instead. The user can set REAL_ALLOW_TEST_EDIT=1."
  fi
  os=$(count "$RE_SKIP" "$2"); ns=$(count "$RE_SKIP" "$3")
  if [ "$ns" -gt "$os" ]; then
    rh_block "The edit of $1 adds a skip or only marker (.skip, .only, xit, pytest.mark.skip and the like). Do not skip tests. Fix the test. The user can set REAL_ALLOW_TEST_EDIT=1."
  fi
  ot=$(count "$RE_TRIVIAL" "$2"); nt=$(count "$RE_TRIVIAL" "$3")
  if [ "$nt" -gt "$ot" ]; then
    rh_block "The edit of $1 adds a trivial assertion (expect(true), assert True and the like). Write an assertion about the real behaviour. The user can set REAL_ALLOW_TEST_EDIT=1."
  fi
}

case $tool in
  Edit)
    f=$(rh_field file_path)
    is_test_path "$f" || exit 0
    check "$f" "$(rh_field old_string)" "$(rh_field new_string)"
    ;;
  Write)
    f=$(rh_field file_path)
    is_test_path "$f" || exit 0
    old=
    [ -f "$f" ] && old=$(cat "$f")
    check "$f" "$old" "$(rh_field content)"
    ;;
  MultiEdit)
    f=$(rh_field file_path)
    is_test_path "$f" || exit 0
    rh_have_jq || exit 0
    old=$(printf '%s' "$rh_input" | jq -r '[.tool_input.edits[]? | .old_string // ""] | join("\n")')
    new=$(printf '%s' "$rh_input" | jq -r '[.tool_input.edits[]? | .new_string // ""] | join("\n")')
    check "$f" "$old" "$new"
    ;;
  apply_patch)
    patch=$(rh_field command)
    [ -n "$patch" ] || exit 0
    paths=$(printf '%s\n' "$patch" | sed -nE 's/^\*\*\* (Update|Add|Delete) File: (.*)$/\2/p')
    [ -n "$paths" ] || exit 0
    while IFS= read -r p; do
      is_test_path "$p" || exit 0
    done <<PATHS
$paths
PATHS
    if printf '%s\n' "$patch" | grep -Eq '^\*\*\* Delete File: '; then
      rh_block "The patch deletes a test file. Do not delete tests. The user can set REAL_ALLOW_TEST_EDIT=1."
    fi
    old=$(printf '%s\n' "$patch" | sed -n 's/^-//p')
    new=$(printf '%s\n' "$patch" | sed -n 's/^+//p')
    check "the patch" "$old" "$new"
    ;;
esac
exit 0
