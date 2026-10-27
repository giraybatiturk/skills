---
description: Print the repo status and the state of the last turn in 8 lines or less.
disable-model-invocation: true
allowed-tools: Bash(sh "${CLAUDE_PLUGIN_ROOT}/scripts/real-status.sh")
---

!`sh "${CLAUDE_PLUGIN_ROOT}/scripts/real-status.sh"`

Show the output above to the user as it is. Add nothing.
