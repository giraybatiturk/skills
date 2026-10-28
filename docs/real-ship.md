# real-ship

`scripts/real-ship.sh` commits your changes, pushes the branch and opens the pull request (GitHub) or the merge request (GitLab). Each step is a separate git command with its own error check. It never merges.

`/real-ship` counts as the explicit user request for commit and push. The Git flow rule "commit or push only when the user asks" is met by the command.

## Use

```sh
real-ship.sh [commit|push] [-m MESSAGE] [--branch NAME] [--dry-run] [--no-suite-check]
real-ship.sh suite
real-ship.sh --help
```

| Call | What it does |
|---|---|
| `real-ship.sh` | Commits when there are changes, pushes, then opens the PR or MR |
| `real-ship.sh commit` | Commits only. It never pushes and never calls `gh` or `glab` |
| `real-ship.sh push` | Commits when there are changes, then pushes. It never calls `gh` or `glab` |
| `real-ship.sh suite` | Runs the long test suite and writes the marker. It changes no file in the work tree |
| `-m MESSAGE` | Sets the commit message. The PR title is the subject of the last commit |
| `--branch NAME` | Runs `git switch -c NAME` first. The changes come with you. Use it when you are on `main` |
| `--dry-run` | Runs every check. Prints a `would run:` line for each change. Changes nothing |
| `--no-suite-check` | Turns a missing or old suite marker into a warning |

The mode word can be in any position. Any other word or flag is an error with exit code 2. This includes `--force`, `--no-verify` and `-a`.

Without `-m`, the script writes an English message from the changed files: `Update 3 files: a.sh, b.md, c.txt`. A longer list ends with `and 2 more`.

## Output

stdout holds only the result lines. Output of git, hooks, `gh` and `glab` goes to stderr.

A full ship prints three lines:

```
committed abc1234 "Update 1 file: a.txt"
pushed feat/x
[PR #18](https://github.com/OWNER/REPO/pull/18)
```

- Line 1 is `nothing to commit, HEAD abc1234 "<subject>"` when there was nothing to commit.
- On GitLab, line 3 is `[MR !18](URL)`.
- `commit` prints line 1 only. `push` prints lines 1 and 2.
- When the PR already exists, the script prints its link and exits with 0. The output of `gh` or `glab` must say `already exists`.

Exit codes: 0 for success, 1 for a refusal or a failed step, 2 for a usage error.

## Refusals

A refusal is one line, and it is the last line of stderr:

```
real-ship: refused: <reason>. Next: <action>.
```

The script checks everything before it changes anything. It refuses in these cases:

- The folder is not a git work tree, or the repo has no commit.
- HEAD is detached.
- The branch is `main`, `master`, the default branch of `origin` or the base branch. Use `--branch feat/<short-name>`.
- The `--branch` name is not valid, already exists or is protected.
- There is no `origin` remote, no known base branch, an unknown host, or no `gh` or `glab` on PATH.
- There is nothing to commit, or nothing to commit or push.
- A changed or staged file has a secret-like name. The match ignores case. The names are `.env`, `.env.*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa*`, `id_ed25519*`, `id_ecdsa*`, `id_dsa*`, `credentials` and `credentials.json`. The names `.env.example`, `.env.sample`, `.env.template`, `.env.dist` and `*.pub` are allowed.
- A staged secret-like file counts even when it is gone from the work tree. A plain deletion is allowed.
- A file under `.real/` is already staged. The script never stages `.real/` itself.
- A file name has a quote, a newline, a tab or a backslash.
- The commit fails. A hook of the repo can cause this. The script never skips a hook.
- The push fails. The commit stays on the branch. Run the same command again after you fix the cause.
- The PR or MR is not created. The branch is already pushed.
- The long test suite has not passed on this state. See the suite marker below.

The script stages the changed files by name. It never uses `git add -A`, `git add .`, `git add -u` or `git commit -a`. It never forces a push. It never skips a hook.

The script pushes with a full refspec. A `remote.origin.push` setting cannot send the branch to another name.

## Settings

Each key has an environment variable. A line in the `.real-hooks` file of the repo root sets the same value. Git config is the last choice.

| Key | Environment variable | Git config | Use |
|---|---|---|---|
| `real-ship.base` | `REAL_SHIP_BASE` | `real.hooks.real-ship.base` | The target branch of the PR or MR. Default: the default branch of `origin`, else `main`, else `master` |
| `real-ship.language` | `REAL_SHIP_LANGUAGE` | `real.hooks.real-ship.language` | The language of the generated message. The script has English only. Another value gives a warning |
| `real-ship.suite` | `REAL_SHIP_SUITE` | `real.hooks.real-ship.suite` | The command of the long test suite. A value turns on the marker check |
| `real-ship.host` | `REAL_SHIP_HOST` | `real.hooks.real-ship.host` | `github` or `gitlab`. Default: found from the host part of the `origin` URL |

Example `.real-hooks` lines:

```
real-ship.base = develop
real-ship.suite = npm run test:all
```

## Suite marker

The marker is optional. It is off until `real-ship.suite` has a value.

1. Run `real-ship.sh suite`. It runs the command from the repo root. On success it writes a marker in the git folder and prints `suite passed <fp7>`.
2. Run `/real-ship`. A `push` or full ship checks the marker. A `commit` does not check it.

The marker holds a fingerprint of the names and contents of all files, except `.real/` and ignored files. A change to any file makes the marker old. A commit does not change the fingerprint, so `commit` then `push` keeps the marker valid.

The script never runs the long suite inside a ship. A long suite can take a long time. Run it on purpose.

## PR body

The body starts with `Commits:` and one line for each commit between the base branch and HEAD.

When `.real/contract.md` exists and `real-contract.sh` is in the same folder as `real-ship.sh`, the body adds the output of `real-contract.sh report`. When that call fails, the script prints a warning and keeps the commit list.

## Install

- Plugin install: the file `commands/real-ship.md` is part of the plugin. The command runs `${CLAUDE_PLUGIN_ROOT}/scripts/real-ship.sh`.
- Without the plugin: copy `commands/real-ship.md` to `~/.claude/commands/` or to `.claude/commands/` in your repo. Set `REAL_SKILLS_HOME` to the skills checkout.
- omp: add the command module from `hooks/README.md`. That sketch is not tested.
- Codex: there is no command file. The agent calls `scripts/real-ship.sh` by name.

## Limits

- It never merges. Only you merge.
- It needs git 2.26 or later and `gh` or `glab` for a full ship.
- It does not run the long test suite. It checks a marker.
- A commit hook of the repo can make a long run. The script waits for it.
- The host comes from the host part of the `origin` URL. A host name with neither `github` nor `gitlab` needs `real-ship.host`. A local path is matched as a whole.
- The script reads the link from the output of `gh` or `glab`. A tool that prints no link gives a refusal. After a failed create, the script reads a link only when the output says `already exists`.
- It makes no commit message in a language other than English. Use `-m`.
- It does not handle a product-specific publish flow. Add that flow in your own overlay.
- The test is `sh scripts/test-real-ship.sh`. It uses stubs for `gh` and `glab`.
