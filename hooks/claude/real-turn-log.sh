#!/bin/sh
# real-hooks-managed
# Turn log hook for the events UserPromptSubmit and Stop. Works in Claude Code and in Codex.
# It records the turn in the state folder of the repo. The files are listed in real-state-lib.sh.
#   UserPromptSubmit: turn_start, and last_request (the prompt, one line, masked, 160 characters).
#                     A prompt that starts with /real-status writes only status_prompt. The record of the last real turn stays.
#                     A real prompt removes status_prompt.
#   Stop:             turn_end, state (the text after "STATE:" in the reply) and, with jq, jobs (background tasks).
#                     While status_prompt is set, a Stop with no STATE line changes nothing: it ends the /real-status turn.
# Both events also write the handoff file (see real-state-lib.sh). real-context.sh reads it at SessionStart.
# A /real-status prompt and a Stop that this hook skips do not change it. The turn folder write comes first: no write, no handoff.
# It prints nothing and always exits 0. It ignores the events of a subagent (the input has agent_id).
# Turn off: REAL_TURN_LOG=0. The last Stop wins, also when stop_hook_active is true.

exec >/dev/null 2>&1
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/real-state-lib.sh"
set -f

[ "${REAL_TURN_LOG:-1}" = 0 ] && exit 0

rs_subagent && exit 0
event=$(rh_field hook_event_name)
case $event in UserPromptSubmit|Stop) ;; *) exit 0 ;; esac

root=$(rs_root "$(rh_cwd)")
[ -n "$root" ] || exit 0
dir=$(rs_dir "$root") || exit 0
now=$(date +%s)

# $1 = last_request, $2 = turn_start (a number or null), $3 = turn_end (a number or null), $4 = state_line, $5 = true or false (clean_end).
# One JSON line, written in a folder with mode 700 as a file with mode 600. A temp file and mv make the write atomic.
handoff() {
  hf=$(rs_handoff "$root") || return 0
  hb=$(git -C "$root" symbolic-ref --short -q HEAD 2>/dev/null || git -C "$root" rev-parse --verify -q --short HEAD 2>/dev/null || true)
  hj=$(printf '{"root":%s,"branch":%s,"last_request":%s,"turn_start":%s,"turn_end":%s,"state_line":%s,"clean_end":%s}' \
    "$(printf '%s' "$root" | rh_json_str)" "$(printf '%s' "$hb" | rh_json_str)" "$(printf '%s' "$1" | rh_json_str)" "$2" "$3" "$(printf '%s' "$4" | rh_json_str)" "$5")
  (
    umask 077
    hd=${hf%/*}
    mkdir -p "$hd" && chmod 700 "$hd" || exit 1
    ht=$hd/.tmp.$$
    printf '%s\n' "$hj" > "$ht" && mv -f "$ht" "$hf" && chmod 600 "$hf" || { rm -f "$ht"; exit 1; }
  )
  return 0
}

case $event in
  UserPromptSubmit)
    prompt=$(rh_field prompt)
    # A /real-status prompt must not replace the record that it shows. UserPromptSubmit ends before the Stop of that turn.
    case $prompt in /real-status|/real-status[[:space:]]*|/*:real-status|/*:real-status[[:space:]]*)
      rs_write "$dir" status_prompt "$now" "$root"
      exit 0 ;;
    esac
    rs_write "$dir" turn_start "$now" "$root" || exit 0
    rm -f "$dir/status_prompt"
    # Mask the full text, then cut: a cut token is never half visible.
    req=$(printf '%s' "$prompt" | tr '\n' ' ' | rs_clean | rs_mask | rs_cut 160)
    [ -n "$req" ] && rs_write "$dir" last_request "$req" "$root"
    handoff "$req" "$now" null "" false
    ;;
  Stop)
    st=$(rh_field last_assistant_message | rs_clean | rs_state_line | rs_mask | rs_cut 200)
    # The /real-status turn prints the script output and adds no STATE line. A reply with a STATE line is real work,
    # for example a turn that a finished background job starts with no prompt. status_prompt stays until a real prompt.
    [ -n "$st" ] || [ -z "$(rs_read "$dir" status_prompt "$root")" ] || exit 0
    rs_write "$dir" turn_end "$now" "$root" || exit 0
    if [ -n "$st" ]; then rs_write "$dir" state "$st" "$root"; else rm -f "$dir/state"; fi
    jobs=
    if rh_have_jq; then
      # Each entry of background_tasks is one task: "<type>: <description, else command>". A separator byte keeps a task on one line.
      jobs=$(printf '%s' "$rh_input" | jq -j '(.background_tasks // [])[]? | (try ((.type // "task") + ": " + (.description // .command // "")) catch empty) + "\u0001"' | tr '\n\001' ' \n' | rs_clean | rs_mask | rs_cut 120 | awk 'NF' | head -n 5)
    fi
    if [ -n "$jobs" ]; then rs_write "$dir" jobs "$jobs" "$root"; else rm -f "$dir/jobs"; fi
    ts=$(rs_read "$dir" turn_start "$root")
    rs_num "$ts" || ts=null
    handoff "$(rs_read "$dir" last_request "$root")" "$ts" "$now" "$st" true
    ;;
esac
exit 0
