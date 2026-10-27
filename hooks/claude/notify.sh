#!/bin/sh
# real-hooks-managed
# Notification hook. Matcher for Claude Code: permission_prompt|idle_prompt
# For Codex, use it on the PermissionRequest event (Codex has no Notification event).
# It sends a desktop notification and, when REAL_NOTIFY_WEBHOOK is set, an HTTP POST.
#   macOS: osascript.  Linux: notify-send (when it exists).
#   REAL_NOTIFY_WEBHOOK: the URL, from the environment. Never put a URL or token in a file of the repo.
#   REAL_NOTIFY_WEBHOOK_FIELD: the JSON field that holds the text. Default: text.
#   REAL_NOTIFY=0 turns the hook off.
# The hook never blocks and always exits 0.

. "$(dirname "$0")/lib.sh"
set -f

[ "${REAL_NOTIFY:-1}" = 0 ] && exit 0

event=$(rh_field hook_event_name)
case $event in
  Notification)
    case $(rh_field notification_type) in
      permission_prompt|idle_prompt) ;;
      *) exit 0 ;;
    esac
    title=$(rh_field title)
    msg=$(rh_field message)
    ;;
  PermissionRequest)
    title="Codex"
    msg="Codex needs your approval for $(rh_field tool_name)."
    ;;
  *) exit 0 ;;
esac
[ -n "$title" ] || title="Agent"
[ -n "$msg" ] || msg="The agent needs your attention."
project=$(basename "$(rh_root)")

os=${REAL_NOTIFY_OS:-$(uname -s 2>/dev/null)}
case $os in
  Darwin)
    if command -v osascript >/dev/null 2>&1; then
      osascript -e 'on run argv' -e 'display notification (item 1 of argv) with title (item 2 of argv)' -e 'end run' "$msg" "$title ($project)" >/dev/null 2>&1
    fi
    ;;
  Linux)
    if command -v notify-send >/dev/null 2>&1; then
      notify-send "$title ($project)" "$msg" >/dev/null 2>&1
    fi
    ;;
esac

if [ -n "${REAL_NOTIFY_WEBHOOK:-}" ] && command -v curl >/dev/null 2>&1; then
  field=${REAL_NOTIFY_WEBHOOK_FIELD:-text}
  body=$(printf '%s: %s (%s)' "$title" "$msg" "$project" | rh_json_str)
  curl -sS -m 5 -X POST -H 'Content-Type: application/json' -d "{\"$field\":$body}" "$REAL_NOTIFY_WEBHOOK" >/dev/null 2>&1
fi
exit 0
