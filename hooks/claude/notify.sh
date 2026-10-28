#!/bin/sh
# real-hooks-managed
# Notification and Stop hook. Matcher for Claude Code Notification: permission_prompt|idle_prompt
# For Codex, use it on the PermissionRequest event (Codex has no Notification event) and on Stop.
# It sends a desktop notification and, when REAL_NOTIFY_WEBHOOK is set, an HTTP POST.
#   macOS: osascript.  Linux: notify-send (when it exists).
#   REAL_NOTIFY_WEBHOOK: the URL, from the environment. Never put a URL or token in a file of the repo.
#   REAL_NOTIFY_WEBHOOK_FIELD: the JSON field that holds the text. Default: text.
#   REAL_NOTIFY=0 turns the hook off.
# Stop: a banner when the last prompt of the user is REAL_NOTIFY_MIN_SECONDS or more in the past (notify.min-seconds, default 120).
#   The last prompt is the later of turn_start (a real prompt) and status_prompt (a /real-status prompt). Both come from
#   real-turn-log.sh (UserPromptSubmit). The title comes from the "STATE:" line of the reply: done, blocked or failed.
#   Without that line the banner says "Turn ended" and shows the first line of the reply.
#   No banner for a retry (stop_hook_active), for a subagent, or when no valid prompt time is recorded.
# The hook never blocks and always exits 0.

. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/real-state-lib.sh"
set -f

[ "${REAL_NOTIFY:-1}" = 0 ] && exit 0

stop=
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
  Stop)
    rh_true stop_hook_active && exit 0
    rs_subagent && exit 0
    root=$(rs_root "$(rh_cwd)")
    [ -n "$root" ] || exit 0
    dir=$(rs_dir "$root") || exit 0
    ts=$(rs_read "$dir" turn_start "$root")
    sp=$(rs_read "$dir" status_prompt "$root")
    # The banner counts from the last prompt of the user. A /real-status prompt counts too, so its own turn gets no banner.
    # A value that is not a whole number is ignored. The files are never written here: real-turn-log.sh runs in parallel.
    start=$(printf '%s\n%s\n' "$ts" "$sp" | awk '/^[0-9]+$/ && length($0) <= 12 && $0 + 0 > m { m = $0 + 0 } END { if (m) printf "%.0f", m }')
    [ -n "$start" ] || exit 0
    min=$(rh_cfg notify.min-seconds)
    case $min in ''|*[!0-9]*) min=120 ;; esac
    awk -v n="$(date +%s)" -v s="$start" -v m="$min" 'BEGIN { exit !(n - s >= m) }' || exit 0
    # The reply is parsed here, not read from real-turn-log.sh: matching hooks run in parallel.
    project=$(basename "$root" | rs_clean)
    reply=$(rh_field last_assistant_message | rs_clean)
    st=$(printf '%s\n' "$reply" | rs_state_line)
    skip=0
    case $(printf '%s' "$st" | tr 'A-Z' 'a-z') in
      done|done' '*|done-*|done:*) title="Done - $project"; skip=4; msg="The turn is done." ;;
      blocked|blocked' '*|blocked-*|blocked:*) title="Waiting for you - $project"; skip=7 ;;
      failed|failed' '*|failed-*|failed:*) title="Failed - $project"; skip=6 ;;
      *) title="Turn ended - $project" ;;
    esac
    if [ "$skip" -gt 0 ]; then
      body=$(printf '%s' "$st" | cut -c "$((skip + 1))-" | sed 's/^[[:space:]:-]*//')
    elif [ -n "$st" ]; then
      body=$st
    else
      body=$(printf '%s\n' "$reply" | rs_first_line)
      msg="The agent stopped."
    fi
    # A body that starts with "-" would be read as an option by notify-send.
    body=$(printf '%s' "$body" | rs_clean | rs_mask | rs_cut 160 | sed 's/^[[:space:]-]*//')
    [ -n "$body" ] && msg=$body
    stop=1
    ;;
  *) exit 0 ;;
esac
[ -n "$title" ] || title="Agent"
[ -n "$msg" ] || msg="The agent needs your attention."
if [ -n "$stop" ]; then
  shown=$title
  text="$title: $msg"
else
  project=$(basename "$(rh_root)")
  shown="$title ($project)"
  text="$title: $msg ($project)"
fi

os=${REAL_NOTIFY_OS:-$(uname -s 2>/dev/null)}
case $os in
  Darwin)
    if command -v osascript >/dev/null 2>&1; then
      osascript -e 'on run argv' -e 'display notification (item 1 of argv) with title (item 2 of argv)' -e 'end run' "$msg" "$shown" >/dev/null 2>&1
    fi
    ;;
  Linux)
    if command -v notify-send >/dev/null 2>&1; then
      notify-send "$shown" "$msg" >/dev/null 2>&1
    fi
    ;;
esac

if [ -n "${REAL_NOTIFY_WEBHOOK:-}" ] && command -v curl >/dev/null 2>&1; then
  field=${REAL_NOTIFY_WEBHOOK_FIELD:-text}
  body=$(printf '%s' "$text" | rh_json_str)
  curl -sS -m 5 -X POST -H 'Content-Type: application/json' -d "{\"$field\":$body}" "$REAL_NOTIFY_WEBHOOK" >/dev/null 2>&1
fi
exit 0
