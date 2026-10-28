# real-await

`scripts/real-await.sh` waits for a human step, then exits. A human step is a login, a download, a merge or a code.
Start it as a background command after you ask the user for the step. The end of the job wakes the agent.
The script makes no model call. It runs in any POSIX shell on Linux and macOS. It needs `ps`, `awk` and `sed`.

## Usage

```
real-await.sh file GLOB [--stable 3]
real-await.sh http URL [--status 200] [--contains TEXT]
real-await.sh pr NUMBER [--state merged|closed]
real-await.sh cmd 'COMMAND'
real-await.sh pid PID
common: --timeout SECONDS  --message TEXT  --interval SECONDS  --no-notify
real-await.sh -h | --help
```

The probe is the first argument. The first other argument is GLOB, URL, NUMBER, COMMAND or PID.
Options use the form `--option VALUE`. They can come before or after that argument. The form `--option=VALUE` is not valid.

## Probes

Each check is one try. The script stops a try that runs more than 10 s, or that runs past the deadline. A stopped try counts as not passed.

| Probe | The check passes when |
|---|---|
| `file` | A regular file that matches GLOB exists, and its size and name list have not changed for `--stable` seconds (default 3) |
| `http` | The URL answers with `--status` (default 200) and, with `--contains`, the body holds TEXT as a fixed string |
| `pr` | The pull request is merged. With `--state closed`, it is closed or merged |
| `cmd` | `sh -c COMMAND` exits 0. It reads no standard input |
| `pid` | `ps -p PID` says that the process does not exist, or the process is a zombie |

Details for each probe:

- `file`: a leading `~/` means your home folder. The shell expands GLOB with no field splitting, so a name with a space works.
- `file`: a name that ends in `.crdownload`, `.part`, `.partial`, `.download` or `.tmp` does not count. It is an unfinished download.
- `file`: a file that exists at the start can pass. Use a GLOB that matches only the expected file. A broad GLOB can pass on an old file.
- `http`: the script runs `curl` with no redirect and no URL globbing. A redirect gives a 3xx code, so give the final URL.
- `http`: the probe calls only the URL that you give. The `pr` probe calls `gh` or `glab`.
- When `REAL_NOTIFY_WEBHOOK` is set, the notification also posts to that URL.
- `http`: TEXT is one line of text.
- `pr`: the script uses `glab` when the `origin` remote holds `gitlab`. Otherwise it uses `gh`, and `glab` when `gh` is not installed.
- `pr`: a CLI error or an unknown state is not a pass. The wait goes on.
- `cmd`: the script prints the last 5 lines of the output of the last try before the last line. Each line is masked and cut to 160 characters.
- `pid`: `kill -0` fails for a process of another user, so that process would look ended. The script uses `ps` instead.
- `pid`: a zombie has ended. Its parent did not call `wait` yet, so `ps` still lists it. The script counts it as ended.

## Options and defaults

| Option | Value | Default |
|---|---|---|
| `--timeout` | Whole seconds, 1 to 86400 | 600. For `pr`: 1800 |
| `--interval` | Whole seconds, 1 to 86400. The pause between two tries | 5 |
| `--stable` | `file` only. Whole seconds, 1 to 86400 | 3 |
| `--status` | `http` only. Three digits, 100 to 599 | 200 |
| `--contains` | `http` only. Not empty | None |
| `--state` | `pr` only. `merged` or `closed` | `merged` |
| `--message` | The text of the notification and of the wait file | A text from the probe |
| `--no-notify` | No value. Sends no notification | Off |

The loop runs a try. On a pass, it stops. At the deadline, it stops with a timeout. Otherwise it sleeps for the interval, cut to the time left.
The last try starts at least 1 s before the deadline. The script counts whole seconds only.

## Output and exit codes

The script prints nothing while it waits. The last line of the output tells the result.

| Last line | Exit code | Meaning |
|---|---|---|
| `HUMAN_STEP_DONE after <s>s` | 0 | The check passed `<s>` seconds after the start |
| `HUMAN_STEP_TIMEOUT` | 3 | The time ran out |
| `real-await: <reason>` on standard error | 2 | Bad input. No notification, no wait file and no network call |
| None | 129, 130, 143 | The script got HUP, INT or TERM |
| `real-await: cannot make a temp folder` on standard error | 1 | `mktemp` failed |

The reason of a bad input never shows an option value. It never shows the GLOB, URL, NUMBER, COMMAND or PID.
The reason can show an unknown probe name or option name. The script masks it.

## The notification

The script calls `hooks/claude/notify.sh` once, after the input is valid and before the first try. It sends no second notification at the end.
The input of `notify.sh` is a Notification event of the type `idle_prompt`. The title is `Waiting for you`. The message is `<message>, times out in <N> min`.
`<N>` rounds up. A timeout under 60 s shows `<N> s`.

The default message depends on the probe:

- `file ~/Downloads/x.pdf`
- `URL https://host/path`
- `PR 18 merged`
- `command <the first 40 characters>`
- `process 1234`

The message is cleaned, masked and cut to 160 characters. `--no-notify` and `REAL_NOTIFY=0` turn the notification off.
The script ignores the exit code and the output of `notify.sh`.

## The wait file

While the script waits, it writes the file `wait.<pid>` in the state folder of the repo. The folder is the same as for the turn log.
The file holds one line: `<start> <deadline> <probe> <message>`. The times are epoch seconds. The script writes it with the owner check of the state library.
A failed write does not stop the wait.

The script removes the file at the end, and on INT, TERM and HUP. The same cleanup stops the running try and removes the temporary folder.
Two waits in one repo have two files, because each file has the PID of its own script.
A wait that gets KILL cannot remove its file. A new wait removes the files that have a past deadline or a PID that does not run.

`scripts/real-status.sh` reads these files. It prints one line: `waiting: <message> (<time> left); <message> (<time> left)`.
The line shows at most 3 waits. It skips a file with a past deadline or with a PID that does not run.

## How an agent uses it

1. Ask the user for the step. Say what to do and how long the wait lasts.
2. Start the script as a background command.
3. Work on independent things inside the contract scope while it waits. Do not touch the files that the human step changes.
4. When the job ends, read the last line. On `HUMAN_STEP_DONE`, continue with no message from the user.
5. When the user types "done" first, stop the wait. Stop only its own PID. Then run the same check once with `--no-notify` and a small `--timeout`, for example 5.
6. On `HUMAN_STEP_TIMEOUT`, end the turn with `STATE: blocked - <what>`. The Stop hook shows that text as the banner.

How each client runs a background command:

- omp: a bash call moves to the background after 60 s. The finished job wakes the agent.
- Claude Code: use a background Bash command. It wakes the agent at the end.
- Codex: not measured.

Examples:

```
sh scripts/real-await.sh file '~/Downloads/report-*.pdf' --message 'download the report'
sh scripts/real-await.sh pr 18 --state merged
sh scripts/real-await.sh http https://staging.example.invalid/health --contains ok
sh scripts/real-await.sh cmd 'test -f /tmp/code-entered' --timeout 300
```

## Browser login recipe

The script has no browser probe. It reads nothing from a browser. Use this recipe for a login:

1. Ask the user to log in, in the browser session of the agent.
2. Wait in the browser tool for a visible signed-in element, such as the user menu, or for the page title. Use a timeout of 10 minutes.
3. Continue when the element shows. On a timeout, end the turn with `STATE: blocked - <what>`.

Never read cookies, tokens or passwords. Never type a password. Never solve a captcha.

## Limits

- A process that detaches itself (a double fork) can escape the stop of a try. The stop sends TERM, then KILL after 1 s, to the try and its descendants.
- A background process that COMMAND starts and does not wait for keeps running after the try ends. Each try starts one more. The script cannot stop it. Make COMMAND wait for its children, for example end it with `wait`.
- A broad GLOB can pass on an old file.
- A one-shot `claude -p` run is not woken: the run ends before the job ends.
- The script finds descendants with `ps -A -o pid= -o ppid=`. It does not use job control, `setsid`, `timeout` or `pkill`.
- The output of a `cmd` try goes to a temporary file. A command that prints a lot for 10 s fills that file.

## Test

Run `sh scripts/test-real-await.sh`. It uses temporary repos, a temporary HOME and stub tools. It takes 1 to 2 minutes.
