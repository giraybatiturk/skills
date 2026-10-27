---
description: Commit, push and open the pull request or merge request. Never merges.
argument-hint: [commit|push] [-m MESSAGE] [--branch NAME] [--dry-run] [--no-suite-check]
---

`/real-ship` is the explicit user request to commit and push. The Git flow rule "commit or push only when the user asks" is met.

Run this one command:

```sh
sh "$REAL_SKILLS_HOME/scripts/real-ship.sh" $ARGUMENTS
```

In a plugin install, run `sh "${CLAUDE_PLUGIN_ROOT}/scripts/real-ship.sh" $ARGUMENTS` instead.

If the script is not found, tell the user to set `REAL_SKILLS_HOME` to the skills checkout. Then stop.

Rules:

- Pass the arguments as they are. Do not add flags.
- Add `--no-suite-check` only when the user typed it.
- Do not run `git commit`, `git push`, `gh` or `glab` yourself for this request.
- The user gave no `-m` and the project rule sets another commit language. Write the message in that language and pass it with `-m`.
- Show the stdout lines to the user as they are.
- On a refusal, show the one refusal line and stop. Do not work around a refusal.
- Never merge.
