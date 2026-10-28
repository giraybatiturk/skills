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
| `hooks/claude/protect-secrets.sh` | PreToolUse, file tools and Bash | Read, edit and write access to `.env*`, `*.pem`, `id_rsa` and `credentials`. It allows `.env.example` |
| `hooks/claude/protect-tests.sh` | PreToolUse, Edit and Write | An edit of a test file that removes tests, adds `.skip`, `.only` or `xit`, or adds a trivial assertion |
| `hooks/claude/post-format.sh` | PostToolUse, Edit and Write | Nothing. It formats the edited file and runs a syntax check. A failed check gives the agent the error |
| `hooks/claude/stop-gate.sh` | Stop | The end of a turn while the typecheck, the lint or the tests fail |
| `hooks/claude/notify.sh` | Notification | Nothing. It sends a desktop or webhook message when the agent waits for you |
| `hooks/claude/session-start.sh` | SessionStart | Nothing. It warns you when the git hooks are not active |

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
| `REAL_SAFE_DELETES="a b"` | Adds names to the safe-delete list of the dangerous-command guard |
| `REAL_SECRET_ALLOW="a b"` | Adds file names that the secret guard allows |

Set the variable in the shell that starts the agent, or in front of one git command: `REAL_ALLOW_MAIN=1 git commit ...`.

The notifier reads two more variables. `REAL_NOTIFY_WEBHOOK` holds a webhook URL, and `REAL_NOTIFY_WEBHOOK_FIELD` names the JSON field for the text. Set them in your environment. Never write a URL or a token in a file of a repo.

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

Notes for each client:

- Claude Code. The matcher of a PreToolUse hook is a tool name, such as `Bash`, or a list such as `Edit|Write`. A hook that prints JSON must exit with 0. Exit 2 blocks and sends stderr to the agent.
- Codex. The matcher `apply_patch` also accepts the names `Edit` and `Write`. The hook input still says `apply_patch`. The patch text is in `tool_input.command`. The scripts here read that text for the secret guard and the test guard. Codex does not support `ask`, so the example runs the dangerous-command guard with `REAL_ASK_MODE=deny`. Codex hooks need a trust review before they run.
- omp. It has no shell-command hooks. A hook is a TypeScript module in `.omp/hooks/pre/`. It calls `pi.on("tool_call", ...)` and returns `{ block: true, reason }`. This repo has no omp module. See the sketch below.

Sources:

- Claude Code: https://code.claude.com/docs/en/hooks and https://docs.claude.com/en/docs/claude-code/hooks-guide
- Codex: https://learn.chatgpt.com/docs/hooks
- omp: https://omp.sh/docs/hooks and https://omp.sh/docs/extension-authoring

### Sketch for omp (not tested)

This sketch is not tested. It calls the Claude Code script for the dangerous-command guard. It shows the idea only.

```ts
// .omp/hooks/pre/real-dangerous.ts
import { spawnSync } from "node:child_process";
import { isToolCallEventType, type ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

export default function realGuard(pi: ExtensionAPI) {
  pi.on("tool_call", (event) => {
    if (!isToolCallEventType("bash", event)) return;
    const input = JSON.stringify({ tool_name: "Bash", tool_input: { command: event.input.command } });
    const run = spawnSync("/ABSOLUTE/PATH/TO/skills/hooks/claude/dangerous-command.sh", {
      input,
      env: { ...process.env, REAL_ASK_MODE: "deny" },
      encoding: "utf8",
    });
    if (run.status === 2) return { block: true, reason: run.stderr.trim() };
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
- A user can bypass any hook. CI is the only enforcement.

## Test

Run `sh scripts/test-hooks.sh`. The script makes temporary repos and a temporary HOME. It does not touch your files or your git config. It runs the Claude Code hook tests two times: with `jq` and without `jq`.
