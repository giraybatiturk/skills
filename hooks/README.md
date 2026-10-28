# Hooks for real work

This folder holds guard hooks for git and for coding agents. A hook is a small script. A tool runs it at a fixed point, and the script can block the action.

This repo installs nothing by itself. You copy the hooks on purpose. `scripts/install-hooks.sh` copies the git hooks into one repo that you name. It prints the agent settings, and you merge them by hand.

Agent hooks help the agent, but they do not enforce a rule. Only the git hooks and your CI can enforce a rule. Codex says this about its own hooks: use them as a guardrail, not as a complete enforcement boundary.

## What is in this folder

Git hooks work with any tool, because git runs them.

| Hook | Runs at | What it blocks |
|---|---|---|
| `hooks/git/pre-commit` | `git commit` | A commit on `main`, `master` or the default branch of `origin` |
| `hooks/git/real-coverage` | `git commit`, called by pre-commit | A new page, route handler or server action that has no test |
| `hooks/git/pre-push` | `git push` | A token in the pushed commits. In a public repo it also blocks your private patterns |

The pre-commit hook also prints a warning for an em dash or a title-case heading in an added `.md` line. The warning does not block.

Agent hooks run in Claude Code. Most of them run in Codex too.

| Hook | Event | What it blocks |
|---|---|---|
| `hooks/claude/pre-tool-use.sh` | PreToolUse, Bash | `git commit` and `git push` in one command, a commit on `main`, `--no-verify`, a `core.hooksPath` override, a bypass variable set inside the command |
| `hooks/claude/dangerous-command.sh` | PreToolUse, Bash | Denies `rm -rf` on broad targets, a force push to `main` and `curl \| sh`. Asks for `git reset --hard`, `git clean -fd`, other force pushes, other risky `rm -rf` and `DROP TABLE` |
| `hooks/claude/real-open-guard.sh` | PreToolUse, Bash | A direct `open`, `xdg-open`, `python -m webbrowser` or a browser start that is not headless. It allows `real-show.sh` |
| `hooks/claude/real-approvals-hook.sh` | PreToolUse, every tool (`*`) | What the approvals table says. A `deny` rule blocks. An `ask` rule asks with the reason. An unlisted MCP tool with a write verb asks. A write by the agent to the table or the grants folder is blocked |
| `hooks/claude/protect-secrets.sh` | PreToolUse, file tools and Bash | Read, edit and write access to `.env*`, `*.pem`, `id_rsa` and `credentials`. It allows `.env.example` |
| `hooks/claude/protect-tests.sh` | PreToolUse, Edit and Write | An edit of a test file that removes tests, adds `.skip`, `.only` or `xit`, or adds a trivial assertion |
| `hooks/claude/post-format.sh` | PostToolUse, Edit and Write | Nothing. It formats the edited file and runs a syntax check. A failed check gives the agent the error |
| `hooks/claude/real-ui-track.sh` | PostToolUse, Edit, Write and apply_patch | Nothing. It writes the time of an edit of a UI file to `.real/ui-dirty`. It runs only when `ui.url` is set |
| `hooks/claude/stop-gate.sh` | Stop | The end of a turn while the typecheck, the lint or the tests fail |
| `hooks/claude/real-ui-stop.sh` | Stop | The end of a turn, once for each UI edit, until `real-shot.mjs --after` has run. It runs only when `ui.url` is set |
| `hooks/claude/notify.sh` | Notification | Nothing. It sends a desktop or webhook message when the agent waits for you |
| `hooks/claude/real-turn-log.sh` | UserPromptSubmit and Stop | Nothing. It records the turn: start time, request, end time, `STATE:` line and background jobs |
| `hooks/claude/notify.sh` | Stop | Nothing. It sends a banner when a turn of 120 s or more ends |
| `hooks/claude/session-start.sh` | SessionStart | Nothing. It warns you when the git hooks are not active |
| `hooks/claude/real-context.sh` | SessionStart | Nothing. It gives the agent the repo facts and you a recap of the last session |

The folder `hooks/claude/` holds the scripts for both clients. The name stays, because the first client was Claude Code.

## Install

Read `scripts/install-hooks.sh --help` first. Use `--print` to see what the script would do. The dry run changes nothing.

```sh
scripts/install-hooks.sh --print /path/to/repo
scripts/install-hooks.sh /path/to/repo
scripts/install-hooks.sh --hooks-path /path/to/hooks-folder /path/to/repo
scripts/install-hooks.sh --uninstall /path/to/repo
```

The script follows these rules:

- It copies `pre-commit`, `pre-push` and `real-coverage` into the repo.
- It backs up each existing hook that is not a real hook. The backup name ends in `.real-backup-` and a timestamp.
- It refuses to continue when `core.hooksPath` is already set. Use `--hooks-path` to choose a folder yourself.
- With `--hooks-path`, it copies the hooks into your folder. It sets `core.hooksPath` in the local git config of that repo only.
- With `--uninstall`, it removes only the files that carry the marker `real-hooks-managed`. It restores the newest backup.
- It never edits `~/.claude/settings.json`, `~/.codex` or the global git config.

For the agent hooks, the script prints the Claude Code settings with your absolute path. Merge the text into `~/.claude/settings.json` or into `.claude/settings.json` of the repo. The same text is in `hooks/claude/settings.example.json`, with the placeholder `/ABSOLUTE/PATH/TO/skills`.

For Codex, copy `hooks/codex/hooks.example.json` to `~/.codex/hooks.json` or to `<repo>/.codex/hooks.json`. Replace the placeholder path. Codex asks you to review and trust each hook before it runs.

## Settings

Each setting has an environment variable. A file in the repo sets the same value. Git config sets it too.

### Test coverage

The check reads these keys: `pages`, `actions`, `tests`, `ignore` and `enabled`. A key can repeat. A key that you set replaces the default globs for that key.

- Put the keys in a `.real-tests` file in the repo root. Use one `key = glob` for each line.
- Or set them with git config: `git config --add real.tests.pages 'src/routes/**/+page.svelte'`.
- `hooks/examples/real-tests.example` shows a SvelteKit setup.

The default globs fit Next.js. They cover the app router and the pages router, with or without `src/`. A route handler (`route.ts` or `pages/api`) counts as an action. A file named `actions.ts` counts as an action file too.

A test covers an item when a test file contains the route path or the action name. A test file is any file that matches the `tests` globs. The test can be in the same commit or already in the repo. A modified page is not checked. Only new pages are checked. For a modified route handler, only a newly added `GET`, `POST`, `PUT`, `PATCH` or `DELETE` export is checked.

When the check blocks a commit, it lists each item and what to do:

1. Run `/real-test <url>` to generate the specs.
2. Or set `REAL_ALLOW_UNTESTED=1` for one commit.
3. Or change the globs.

### Private patterns and tokens

- Mark a repo as public with `git config real.public true`, or add an empty `.real-public` file.
- Write your private patterns in `~/.config/real/private-patterns.txt`. Keep this file outside every repo.
- One pattern for each line. A pattern is a fixed string and the match ignores case. A line that starts with `re:` is an extended regular expression. A line that starts with `#` is a comment.
- Set another file with `REAL_PRIVATE_PATTERNS` or `git config real.patternsFile`.

The pre-push hook scans only the lines that you add. A hit prints at most 3 lines, cut to 100 characters. A token hit prints the token type and never the token. Common token types are GitHub, AWS, Slack, Stripe, Google, GitLab, OpenAI-style keys, private key blocks and JWT. The token scan runs in every repo. Use `git config real.tokenScan false` to turn it off.

### Agent hook settings

Put these keys in a `.real-hooks` file in the repo root. Use one `key = value` for each line. An environment variable `REAL_<KEY>` wins over the file. Git config `real.hooks.<key>` is the last choice.

| Key | Use |
|---|---|
| `gate.typecheck`, `gate.lint`, `gate.test` | The commands of the Stop gate. Without them, the gate uses the npm scripts `typecheck`, `lint` and `test` when `package.json` has them |
| `gate.max-retries` | How many times the Stop gate blocks in a row. Default: 2 |
| `format.cmd` | The formatter. Write `{file}` where the path goes. Default: the local `prettier`, when it exists |
| `check.cmd` | The check of one file. Defaults: `node --check`, `python3 -m py_compile` and `sh -n` |
| `open.guard` | `off` turns off the open guard. Default: on |
| `notify.min-seconds` | The shortest turn, in seconds, that gets a banner at Stop. Default: 120 |
| `ui.url` | The address of your dev server, for example `http://127.0.0.1:5173/`. The two UI hooks do nothing without it |
| `ui.globs` | The files that count as UI files. A comma list of patterns, where `*` also matches `/`. Default: `*.tsx,*.jsx,*.css,*.scss,*.html,*.vue,*.svelte` |
| `ui.target-min` | The smallest touch target for `real-shot.mjs`, in px. A whole number from 1 to 200. Default: 40 |

`hooks/examples/real-hooks.example` shows the file.

## Bypass variables

A bypass is for one command. The user sets it. The agent hooks block an agent that sets a bypass inside its own command.

| Variable | Bypasses |
|---|---|
| `REAL_ALLOW_MAIN=1` | The commit guard on `main` |
| `REAL_ALLOW_UNTESTED=1` | The test coverage check |
| `REAL_ALLOW_PRIVACY=1` | The pre-push scan |
| `REAL_ALLOW_TEST_EDIT=1` | The test-weakening guard |
| `REAL_ALLOW_UNVERIFIED=1` | The Stop gate |
| `REAL_STOP_GATE=0`, `REAL_POST_FORMAT=0`, `REAL_NOTIFY=0`, `REAL_SESSION_CHECK=0` | The Stop gate, the formatter, the notifier and the session check |
| `REAL_TURN_LOG=0` | The turn log |
| `REAL_CONTEXT=0` | The context hook |
| `REAL_UI_LOOP=0` | The two UI hooks, `real-ui-track.sh` and `real-ui-stop.sh` |
| `REAL_OPEN_GUARD=off` | The open guard. Set it in the environment of the hook, not inside the command |
| `REAL_SAFE_DELETES="a b"` | Adds names to the safe-delete list of the dangerous-command guard |
| `REAL_SECRET_ALLOW="a b"` | Adds file names that the secret guard allows |

Set the variable in the shell that starts the agent, or in front of one git command: `REAL_ALLOW_MAIN=1 git commit ...`.

The notifier reads two more variables. `REAL_NOTIFY_WEBHOOK` holds a webhook URL, and `REAL_NOTIFY_WEBHOOK_FIELD` names the JSON field for the text. Set them in your environment. Never write a URL or a token in a file of a repo.

## Approvals table

The approvals table is one flat YAML file. It lists which tool calls and commands run alone, which ask you, and which are denied. Each rule has a reason.

```yaml
- id: tracker-write
  tool: mcp__tracker__*create*|mcp__tracker__*update*
  mode: ask
  why: Show the text first and wait for approval.
- id: merge
  command: gh pr merge|glab mr merge
  mode: deny
  why: Only the owner merges.
```

Each rule starts with `- id:` at column 1. The next lines start with two spaces. A rule has `id`, `mode` and `why`. It has one of `tool` or `command`.

- `id`: lower case letters, digits and `-`, at most 64 characters. The id is unique in one file.
- `tool`: tool names. A `*` matches any text and a `?` matches one character. The match is case sensitive. Split alternatives with `|`.
- `command`: command words with the same wildcards. It applies to the `Bash` tool only. Split alternatives with `|`.
- `mode`: `auto`, `ask` or `deny`.
- `why`: one line of text. The agent and you see it.

A value has at most 500 characters. A rule has at most 20 alternatives. A table has at most 500 rules and 128 KiB. The parser ignores blank lines and lines that start with `#`. `hooks/examples/approvals.example.yml` shows the format.

### Lookup and conflicts

- `REAL_APPROVALS` names one table. Then only that table applies.
- Without it, `.real/approvals.yml` in the repo and `~/.config/real/approvals.yml` both apply. A repo table cannot remove a `deny` rule of your own table.
- With no table, the hook does nothing.
- When two rules match, the stricter mode wins: `deny`, then `ask`, then `auto`. `real-approvals.sh check` prints each conflict.

### Modes

- `deny`: the hook exits with code 2. The agent sees `ID: WHY`.
- `ask`: the client asks you and shows `ID: WHY`. With `REAL_ASK_MODE=deny` the hook denies instead and prints a grant hint.
- `auto`: the hook prints nothing. The hook never prints `allow`, so the table never skips a prompt of the client.

### Defaults and errors

- An unlisted MCP tool with a write verb in its name asks. The id is `default-write`. A word of the tool name must equal the verb.
- The verbs are `create update delete send post publish move merge remove add set edit write comment submit share upload archive deploy`.
- The name `mcp__x__get_settings` has no write verb, because `settings` is not `set`. The name `mcp__x__createIssue` has the verb `create`.
- A table with an error makes every MCP tool with a write verb ask. The id is `broken-table`. This holds also when a rule of another table says `auto`.
- The hook also shows a warning with the file, the line and the error. The rules of a valid table still apply. The rules of the broken table do not apply.
- A file over 128 KiB, or with a control byte, counts as a table with an error.

### Grants

- A grant lets one `ask` rule pass for a short time. The file `${XDG_STATE_HOME:-$HOME/.local/state}/real/approvals/RULE_ID` holds `expires=EPOCH`.
- Only you run `real-approvals.sh grant RULE_ID --minutes N`, in a terminal. The command refuses to run without a terminal. A `deny` rule cannot be granted.
- The hook denies a write by the agent to the table or to the grants folder. It also denies `grant` in an agent command. The agent can still run `check`, `explain`, `revoke` and `export-omp`.
- A grant never lifts a `deny` rule or `broken-table`. An expired or malformed grant file is ignored.

### Commands

```sh
scripts/real-approvals.sh check
scripts/real-approvals.sh explain mcp__tracker__create_task
scripts/real-approvals.sh explain gh pr merge 5
scripts/real-approvals.sh grant tracker-write --minutes 10
scripts/real-approvals.sh revoke tracker-write
scripts/real-approvals.sh export-omp --tools names.txt
```

- `check` prints the tables, the rules, the conflicts and the grants. It exits with 1 when a table has an error.
- `explain` prints one line: `MODE ID: WHY`. One word such as `mcp__x__y` or `Write` is a tool name. Other text is a Bash command.
- `grant` and `revoke` change the grant file of one rule. `grant` takes 1 to 1440 minutes. The default is 10.
- `export-omp` prints a `tools.approval` block for omp. It writes no file.

### Command matching

The hook splits a command into words outside quotes. A segment ends at `;`, `&&`, `||`, `|`, `&`, a new line, `(` or `)`. The hook also scans the text of `$( )`, backticks, `sh -c` strings and `eval`.

Each word position starts a match. The pattern must match that word, then the words after it. A prefix of the words is enough. So `sudo gh pr merge`, `bash -c 'gh pr merge 1'` and `xargs -n1 gh pr merge` match `gh pr merge`. The text `git commit -m 'gh pr merge'` does not match. The hook uses the base name of the first word, so write `gh` and not `/usr/bin/gh`.

### Codex and omp

- Codex does not support `ask`. The Codex example runs the hook with `REAL_ASK_MODE=deny`. An `ask` rule then denies, and the message names the grant command. Run `grant` in your terminal to let the rule pass.
- omp has `tools.approval`. It maps exact tool names to `allow`, `deny` or `prompt`, and it has no globs. `export-omp` prints the block for the tool names that it knows.
- Give `--tools FILE` with one tool name for each line, written as `mcp__SERVER__TOOL`. The command expands the globs against that list. It also lists the unlisted write tools as `prompt`.
- omp writes the name as `mcp__SERVER_TOOL`, with one underscore. The command converts the names. Merge the block into the omp config by hand.
- Rules for Bash commands run through the adapter with `REAL_ASK_MODE=deny`.

Keep your real table private. This repo has only a generic example.

## Show a result to the user

`scripts/real-show.sh PATH` prints a Markdown link to a file or a folder, and the agent gives that link to you. A web file (`.html`, `.htm`, `.xhtml`, `.svg`) gets a local server link, and `curl` checks the title. `--open` runs `open -g` on macOS for a folder or a file, never for a web page or a URL. `--list` shows the servers and `--stop` ends one or all of them.

## Turn log and status

`real-turn-log.sh` records each turn of the agent. `notify.sh` reads the record at Stop. `scripts/real-status.sh` shows it. The hooks print nothing and always exit 0. They skip the events of a subagent. `real-state-lib.sh` holds the shared helpers. Source it. Do not run it.

The state folder is `${XDG_STATE_HOME:-$HOME/.local/state}/real/turn/<key>/`. The key is the `cksum` of the absolute repo root, written as `<crc>-<length>`. The layout is stable. Later hooks read these files.

| File | Content |
|---|---|
| `root` | The absolute repo root, or the working folder outside git. A reader trusts the folder only when this line matches its own root |
| `turn_start` | Epoch seconds, written at UserPromptSubmit of a real prompt |
| `last_request` | The first 160 characters of the prompt, on one line, with secrets masked. A prompt that starts with `/real-status` does not replace it |
| `turn_end` | Epoch seconds, written at Stop |
| `state` | The text after `STATE:` in the last STATE line of the reply. The hook removes the file when the reply has no STATE line |
| `jobs` | The background tasks that run at the last Stop, one for each line, at most 5. Needs Claude Code and `jq`. The hook removes the file when no task runs |
| `status_prompt` | Epoch seconds, written at UserPromptSubmit of a `/real-status` prompt. While it is set, a Stop with no STATE line changes no file. The next real prompt removes the file |
| `wait.<pid>` | Written by `scripts/real-await.sh` while it waits. One line: `<start> <deadline> <probe> <message>`. The script removes it at the end. Two waits have two files. A new wait removes a file with a past deadline or a dead PID |

A `turn_end` that is older than `turn_start` means a turn runs now, or the last turn ended with no Stop. Each file holds one line, except `jobs`. The hook writes with `umask 077`. The mask covers these values:

- Token prefixes such as `ghp_`, `glpat-`, `sk-`, `sk_live_` and `AKIA`.
- Bearer and Basic values.
- `key=value` pairs for token, secret and password.
- JWT strings.
- A user and password in a URL.
- The rest of a line that holds a private key marker.

The mask runs before the cut, so a cut token is never half visible. A cut counts characters, so it never splits a multi-byte character. The folder holds no handoff data.

The turn log also writes a handoff file for the next session. The path is `${XDG_STATE_HOME:-$HOME/.local/state}/real/handoff/<key>.json`. The key is the same as for the turn folder. `rs_handoff` in `real-state-lib.sh` prints the path. The file holds one JSON line with these keys, in this order:

| Key | Content |
|---|---|
| `root` | The absolute repo root. A reader ignores the file when this is not its own root, because two roots can share a key |
| `branch` | The branch name, the short hash of a detached HEAD, or an empty string outside git |
| `last_request` | The masked request. It is the same text as the file `last_request` |
| `turn_start` | Epoch seconds, or `null` |
| `turn_end` | Epoch seconds. It is `null` while a turn runs, and after a crash |
| `state_line` | The masked text after `STATE:` of the last Stop. It is an empty string when there is none |
| `clean_end` | `false` after a prompt. `true` after a Stop |

A real prompt writes the file with `clean_end` false. A Stop writes it with `clean_end` true. A `/real-status` prompt does not change the file. A Stop that the hook skips does not change it either. The hook writes the file only after the write to the turn folder works. The folder has mode 700 and the file has mode 600. The hook writes a temp file and moves it over the old file. A reader never sees half a line. The context hook ignores a file that is older than 14 days.

A STATE line starts with `STATE:`. Spaces and the characters `*`, `_`, backtick and `>` can come before the word. The last STATE line of the reply counts. The banner reads these forms:

| Line of the reply | Title of the banner | Body of the banner |
|---|---|---|
| `STATE: done` | `Done - <project>` | `The turn is done.` |
| `STATE: done - <text>` | `Done - <project>` | `<text>` |
| `STATE: blocked - <text>` | `Waiting for you - <project>` | `<text>` |
| `STATE: failed - <text>` | `Failed - <project>` | `<text>` |
| `STATE: <other text>` | `Turn ended - <project>` | `<other text>` |
| No STATE line | `Turn ended - <project>` | The first line of the reply, or `The agent stopped.` |

The match of `done`, `blocked` and `failed` ignores case. A dash, a colon or a space can follow the word. The body is masked and cut to 160 characters. A leading dash is removed, because `notify-send` reads it as an option.

The banner comes at Stop when the turn lasted `notify.min-seconds` or longer (default 120). The banner counts from the last prompt of the user, and a `/real-status` prompt counts too. A `/real-status` turn is short, so it gets no banner. A turn that a finished background job starts counts from the last prompt, so it gets a banner. The banner comes from `notify-send` on Linux and from `osascript` on macOS. With `REAL_NOTIFY_WEBHOOK` set, it also posts `<title>: <body>` to the webhook. No banner comes when `stop_hook_active` is true. No banner comes when no valid prompt time is recorded.

`/real-status` prints at most 8 lines, in under 2 seconds. It makes no network call and no model call.

- Line 1: the branch, the number of changed files and the age of the last commit.
- Line 2: the contract task, its status and the number of verified DONE WHEN items. The rule is the same as in the contract report.
- Line 3: the last 3 commands of `.real/evidence.jsonl` with their exit codes.
- Line 4: the turn state, its age and the last request. A running turn shows `running for <age>`.
- Line 5: the background jobs of the last Stop.
- Line 6: `waiting: <message> (<time> left)` for each live `wait.<pid>` file, at most 3, separated by `;`. A file with a past deadline, or with a PID that does not run, is skipped.

A line with no data is skipped. Each line is cleaned, masked and cut to 160 characters. You can run `sh scripts/real-status.sh [DIR]` in any shell.

- Claude Code: `commands/real-status.md` is a plugin command. For a copy outside the plugin, replace `${CLAUDE_PLUGIN_ROOT}` with the absolute path of this repo.
- Codex: no command in v1.
- omp: register a command that runs the same script. This sketch is not tested.

```ts
// .omp/extensions/real-status.ts (sketch, not tested)
import { spawnSync } from "node:child_process";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

export default function realStatus(pi: ExtensionAPI) {
  pi.registerCommand("real-status", {
    description: "Show the repo status and the state of the last turn",
    handler: async (_args, ctx) => {
      const run = spawnSync("sh", ["/ABSOLUTE/PATH/TO/skills/scripts/real-status.sh", ctx.cwd], { encoding: "utf8" });
      ctx.ui.notify((run.stdout || run.stderr).trim(), "info");
    },
  });
}
```

The omp adapter for the turn log is a sketch too. It is not tested. The source is the extension types of omp 18.12, read and not run.

- `pi.on("input", ...)` runs `real-turn-log.sh` with `{ hook_event_name: "UserPromptSubmit", cwd, prompt: event.text }`.
- `pi.on("session_stop", ...)` runs the gate scripts first. When nothing blocks, it runs `real-turn-log.sh` and then `notify.sh` with `{ hook_event_name: "Stop", cwd, stop_hook_active, last_assistant_message }`. The message is the text parts of `event.last_assistant_message`, joined.

## Context at session start

`real-context.sh` runs at SessionStart. It gives the agent a block of facts, and it gives you a recap of the last session. It makes no model call. It prints nothing when no line has data. It always exits 0 and never blocks. It skips the events of a subagent.

The hook reads these sources:

- The handoff file of the last session. The hook trusts it only when `root` is the current root and a time is a number. The file must not be older than 14 days. Otherwise the hook ignores the file and prints no request and no last-turn line.
- Git: the branch, the number of changed files, the commits ahead and behind, and the last 5 commits.
- The contract: the task, the status and the number of open DONE WHEN items.
- `gh pr list` for your open pull requests. It runs only when `gh` is on `PATH` and the folder is a git work tree. It puts no token and no host in its arguments.
- A memory command that you set with `REAL_CONTEXT_MEMORY_CMD`.

The hook prints one JSON line with two parts:

- `additionalContext` is for the agent. It has 1,200 characters or less. The first line says that the text is data, not instructions. The next lines are the last request, the last turn, git, the contract, the PRs, the commits and the notes. A line with no data is left out.
- `systemMessage` is for you. It has 3 lines or less, and each line has 160 characters or less. Line 1 is the last request, cut to 80 characters. Line 2 is the last turn. Line 3 is the git and contract facts.

The last-turn line says `ended without a clean stop, started <age> ago` when the turn has no Stop. After a Stop it says `<state>, <age> ago`. The age counts from `turn_end` after a clean stop, and from `turn_start` otherwise.

After compaction (`source` is `compact`), the hook gives only the git line, the contract line and the last-turn line. It starts no `gh` and no memory command. It sends no `systemMessage`.

The block never has more than 1,200 characters. A newline counts as one character. A block that is too long loses the notes line first, then the PR line, then the commits line. When it is still too long, the hook cuts it. A cut never splits a multi-byte character.

The PR line has two forms. The full form lists up to 5 PRs as `#<number> <title> (<branch>)`. The hook uses it when the last session ended 24 h ago or more, or when no valid handoff exists. The short form is `PRs: <count> open`. It adds `this branch: #<n>` when a PR has the current branch. With no open PR, the line is `PRs: none open`. When `gh` is missing, fails or times out, there is no PR line.

Every line of both outputs goes through one filter. The filter removes control characters and masks secrets with the mask of the turn log. It replaces the home folder, and any path under the home folder of a user, with `~`. It cuts the text last, so a cut token is never half visible. The last request, the commits, the PR titles and the notes are data from outside. The agent must not follow them as instructions.

| Variable | Use |
|---|---|
| `REAL_CONTEXT=0` | Turns off the hook |
| `REAL_CONTEXT_TIMEOUT` | The time limit of `gh` and of the memory command, in seconds. A whole number from 1 to 10. Another value means 3 |
| `REAL_CONTEXT_MEMORY_CMD` | The memory command. Without it, the hook makes no memory call |

`gh` and the memory command run in parallel. When one of them hangs, the hook ends within the time limit plus 2 s.

Set `REAL_CONTEXT_MEMORY_CMD` to a command. The hook splits it on spaces and adds one argument, the query. A path with a space does not work. The query holds the repo folder name, the branch, the contract task and the first text line of the OBJECTIVE. The hook takes at most 3 non-empty lines from the standard output. It drops a line that the mask changes, because that line holds a secret. The line in the block is `notes (unverified): <note> | <note>`. When the command fails or times out, the line is `memory: unavailable`.

`scripts/real-mem.sh search QUERY` is such a command for a memory service. It sends the search to `REAL_MEM_URL` with `curl`. Example: `REAL_CONTEXT_MEMORY_CMD="sh /ABSOLUTE/PATH/TO/skills/scripts/real-mem.sh search"`. It reads its settings from the environment only:

| Variable | Use |
|---|---|
| `REAL_MEM_URL` | The base URL of the service. Required |
| `REAL_MEM_TOKEN_FILE` | The file with the token. Required. Group and others must not read it: use mode 600 |
| `REAL_MEM_USER` | The `user_id` of the search. Required |
| `REAL_MEM_LIMIT` | The number of memories. Default: 3 |
| `REAL_MEM_THRESHOLD` | The lowest score, as a number. Optional |

The script refuses a missing token file and a token file that group or others can read. It refuses a token with a character outside `A-Za-z0-9._~+/=-`. It gives the token to `curl` on standard input. The token is never in an argument, an error message or a log. It exits 0 when it works, 1 on an error and 2 on bad usage. An error is one line on standard error that starts with `real-mem:`. The script reads the reply as `{"results":[{"memory":"..."}]}` or as a top-level array of the same objects.

Put `real-context.sh` after `session-start.sh` and after the contract hook, when you use one, in the same SessionStart group. It does not repeat their text. It gives no git-hooks warning, no SCOPE and no DO NOT TOUCH. The contract line has only the task, the status and the open count. The Claude Code example has no matcher, so the hook also runs after compaction. The Codex example keeps the matcher `startup|resume`.

omp: this mapping is not tested. `pi.on("before_agent_start", ...)` runs `real-context.sh` once for each session. The input is `{ hook_event_name: "SessionStart", source: "startup", cwd }`. The adapter returns `additionalContext` as a hidden message. It shows `systemMessage` as a visible message or as a notify call. Compaction is not checked.
## UI before and after

Two hooks support the `real-shot` mode of `real-test`. Both do nothing until `ui.url` is set.

- `real-ui-track.sh` runs after each edit. When the edit touches a file that matches `ui.globs`, it writes the time to `.real/ui-dirty`.
- `real-ui-stop.sh` runs when the agent wants to stop. If a UI edit came after the last capture, it blocks the stop once. It tells the agent to run `real-shot.mjs --after` and to give you the comparison link.

The hooks keep three state files in the `.real/` folder of the repo:

- `.real/ui-dirty` holds the time of the last UI edit.
- `.real/ui-shot` holds the start time of the last `real-shot.mjs --after` run that worked.
- `.real/ui-nagged` holds the edit time that the Stop hook already blocked for. A new UI edit writes a new time, so the next stop blocks again.

`real-shot.mjs` writes its images and its comparison page to `.real/shots/`. Add `.real/` to `.git/info/exclude`, so that none of these files reach a commit.

## Client support

The hook names come from the official documents. They were checked on 2026-10-27.

| Need | Claude Code | Codex | omp |
|---|---|---|---|
| Format of a hook | `settings.json`, shell commands | `hooks.json`, shell commands | A TypeScript or JavaScript module |
| Block a tool call | Yes. Exit 2, or `permissionDecision` | Yes. Exit 2, or `permissionDecision` | Yes. Return `{ block, reason }` from `tool_call` |
| Ask the user | Yes. `permissionDecision: "ask"` | No. The tool call continues. The hooks here deny instead | Not checked |
| Stop gate | Yes. `Stop` with `decision: "block"` | Yes. Same format | Event `session_stop`. Not checked |
| Format after an edit | Yes. The input has `file_path` | No. An `apply_patch` call has no `file_path` | Not checked |
| Notification event | Yes. `permission_prompt` and `idle_prompt` | No. Use `PermissionRequest` | Not checked |
| Session start | Yes | Yes | Event `session_start` |
| Turn-end banner and turn log | Yes. `UserPromptSubmit` and `Stop` | Yes. Same events | Events `input` and `session_stop`, through an adapter. Not checked |

Notes for each client:

- Claude Code. The matcher of a PreToolUse hook is a tool name, such as `Bash`, or a list such as `Edit|Write`. A hook that prints JSON must exit with 0. Exit 2 blocks and sends stderr to the agent.
- Codex. The matcher `apply_patch` also accepts the names `Edit` and `Write`. The hook input still says `apply_patch`. The patch text is in `tool_input.command`. The scripts here read that text for the secret guard and the test guard. Codex does not support `ask`, so the example runs the dangerous-command guard with `REAL_ASK_MODE=deny`. Codex hooks need a trust review before they run.
- omp. It has no shell-command hooks. A hook is a TypeScript module in `.omp/hooks/pre/`. It calls `pi.on("tool_call", ...)` and returns `{ block: true, reason }`. This repo has no omp module. See the sketch below. An omp module runs the same shell scripts, so `real-open-guard.sh` works there too.

Sources:

- Claude Code: https://code.claude.com/docs/en/hooks and https://docs.claude.com/en/docs/claude-code/hooks-guide
- Codex: https://learn.chatgpt.com/docs/hooks
- omp: https://omp.sh/docs/hooks and https://omp.sh/docs/extension-authoring

### Sketch for omp (not tested)

This sketch is not tested. It runs the Bash scripts `dangerous-command.sh`, `real-open-guard.sh` and `real-approvals-hook.sh` in turn. It blocks on the first exit 2. It shows the idea only.

```ts
// .omp/hooks/pre/real-guards.ts
import { spawnSync } from "node:child_process";
import { isToolCallEventType, type ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const SCRIPTS = ["dangerous-command.sh", "real-open-guard.sh", "real-approvals-hook.sh"];

export default function realGuard(pi: ExtensionAPI) {
  pi.on("tool_call", (event) => {
    if (!isToolCallEventType("bash", event)) return;
    const input = JSON.stringify({ tool_name: "Bash", tool_input: { command: event.input.command } });
    for (const script of SCRIPTS) {
      const run = spawnSync(`/ABSOLUTE/PATH/TO/skills/hooks/claude/${script}`, {
        input,
        env: { ...process.env, REAL_ASK_MODE: "deny" },
        encoding: "utf8",
      });
      if (run.status === 2) return { block: true, reason: run.stderr.trim() };
    }
  });
}
```

### Command for omp (not tested)

This sketch is not tested. It adds the command `/real-ship` to omp. The command sends the instruction of `commands/real-ship.md` to the agent. The agent runs `scripts/real-ship.sh`. Codex has no command file. The agent calls the script by name.

```ts
// .omp/extensions/real-ship.ts
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const SCRIPT = "/ABSOLUTE/PATH/TO/skills/scripts/real-ship.sh";

export default function realShip(pi: ExtensionAPI) {
  pi.registerCommand("real-ship", {
    description: "Commit, push and open the PR or MR. Never merges.",
    handler: async (args: string) => {
      pi.sendUserMessage(
        [
          "/real-ship is the explicit user request to commit and push.",
          `Run one command: sh "${SCRIPT}" ${args.trim()}`,
          "Pass the arguments as they are. Do not add flags. Add --no-suite-check only when the user typed it.",
          "Do not run git commit, git push, gh or glab yourself for this request.",
          "If the user gave no -m and the project rule sets another commit language, write the message in that language and pass it with -m.",
          "Show the stdout lines to the user as they are.",
          "On a refusal, show the one refusal line and stop. Do not work around a refusal.",
          "Never merge.",
        ].join("\n"),
      );
    },
  });
}
```

## What is not included

- **A Stop hook that looks for evidence in the last message.** The idea was to read the last message of the agent and look for proof, such as a test result. A text search is not reliable. A careful agent fails it, and a careless agent passes it. The Stop gate replaces it. The gate runs the real commands, so it needs no guess.
- **A formatter for Codex.** An `apply_patch` call has no `file_path` in the hook input. The Stop gate covers the files that Codex edits.
- **A Notification hook for Codex.** Codex has no such event. `notify.sh` runs on `PermissionRequest` instead.
- **A JSON format for `.real-tests`.** The file is plain text, because a shell script can read it without jq.
- **An edit of `~/.claude/settings.json`.** The installer only prints the settings.
- **The `onFailure` option of the Claude Code hook settings.** It exists in version 2.1.295 and later. The example does not use it, so it works in older versions.

## Limits

- The shell guards read the command text. A command that builds a file name at run time, such as `cat .e*`, is not caught. Block the access in the permission settings of the client too.
- Without `jq`, the scripts read the input with `sed`. This works for the normal input. `MultiEdit` needs `jq`, so the test guard skips it when `jq` is missing.
- A commit message that has `&&` or `;` inside quotes is handled. A message inside a here-document is not.
- The secret guard blocks by file name. It does not look at the content of a file.
- The test-weakening guard counts test declarations. Moving a test to another file counts as a removal. Set `REAL_ALLOW_TEST_EDIT=1` for that move.
- The Stop gate runs the checks of the whole repo. A slow test suite makes every turn slow. Set smaller commands in `.real-hooks`.
- The open guard reads the command text. It does not catch a command built at run time, such as `$BROWSER`, `eval` or a variable that holds `open`. It does not catch `xargs open`, `find -exec open` or `osascript`. It knows only the browser binaries Google Chrome, Chromium and Firefox. Another browser that you start by its path, for example Safari or Edge, is not caught. `open -a` with any app is denied. It reads a here-document as commands, so a line that starts with `open` can cause a false deny. It reads a `-c` string down to three levels. It skips only the wrappers `sudo`, `command`, `exec`, `nohup`, `time` and `env`.
- Matching hooks run in parallel. A banner can come at the first Stop while the Stop gate blocks. A retry (`stop_hook_active` true) gives no banner.
- Two sessions in one repo share one state folder. The last write wins.
- The `jobs` file needs Claude Code and `jq`. Without `jq`, the hook removes it. Without `jq`, the hook reads `agent_id` at any depth. A background task entry with an `agent_id` then makes the hook skip the event.
- The banner needs the permission of the system notifier. When the system blocks it, no banner shows.
- The memory response format is not checked against a live service. `real-mem.sh` reads two shapes only.
- Claude Code runs matching hooks in parallel. The text of `session-start.sh`, the contract hook and `real-context.sh` can come in any order.
- The approvals hook reads the command text. It does not catch a command built at run time, such as `$VAR` or `$(echo gh)`. It does not read a here-document body or the remote string of `ssh`.
- Options between the words of a pattern break the match. The command `gh pr --repo x merge` does not match `gh pr merge`. Write `gh pr *merge*` instead.
- The approvals hook scans a nested `-c` string, `eval` text or `$( )` text down to four levels. A pattern with a glob in its first word is slower than the other patterns.
- A Bash command that is too long or too nested to scan in time gets `ask`. A `deny` that the hook finds first still wins.
- The guard of the approvals table and the grants folder reads text only. A command or a path that builds the name at run time is not caught.
- A grant is a file. A process that writes the file by another path is not caught.
- A user can bypass any hook. CI is the only enforcement.

## Test

Run `sh scripts/test-hooks.sh`. The script makes temporary repos and a temporary HOME. It does not touch your files or your git config. It runs the Claude Code hook tests two times: with `jq` and without `jq`. Run `sh scripts/test-real-show.sh` for the `real-show.sh` helper. That script uses a temporary HOME and stops only the servers that it started.

Run `sh scripts/test-real-status.sh` for `scripts/real-status.sh`. It uses temporary repos, a temporary HOME and a temporary state folder.
Run `sh scripts/test-real-ship.sh` for `real-ship.sh`. That script uses a temporary repo, a bare remote and stubs for `gh` and `glab`. It never calls the real tools.

Run `sh scripts/test-real-context.sh` for the context hook, the handoff file and `scripts/real-mem.sh`. It runs each hook case with `jq` and without `jq`. It uses stubs for `gh`, `curl` and the memory command, so it needs no live service and no token.

Run `sh scripts/test-real-await.sh` for `scripts/real-await.sh`. It uses temporary repos, a temporary HOME and stub tools. It stops only the processes that it started.
For the UI hooks and `real-shot.mjs`, run `node scripts/test-real-shot.mjs` with Playwright and Chromium installed in `skills/engineering/real-check/scripts`.
Run `sh scripts/test-real-approvals.sh` to test the approvals hook and `real-approvals.sh` in a temporary HOME.
