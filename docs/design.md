# cc-restore plan

`cc-restore` lists Claude Code sessions from every project folder, newest first.
The user picks one or more in `fzf`, and each one opens in a new Windows Terminal tab in the current window.

Tests: `bash test/run.sh` (plain bash, because `bats` is not installed).
Exit 0 means all pass, 1 means a test failed, 2 means the test setup is broken.

## Files

| path | role |
|---|---|
| `cc-restore` | the tool, one bash script; symlink to `~/.local/bin/cc-restore` |
| `test/run.sh` | test runner, builds a fake `HOME` per run |
| `test/fixture.sh` | `build_fixture <dir> <live_pid> <dead_pid>` |
| `~/.claude/skills/restore/SKILL.md` | `/restore` skill, created by the implementer |

## CLI

```text
cc-restore                          interactive picker (fzf), then open tabs
cc-restore --list                   machine-readable session list, no fzf
cc-restore --dry-run [--fork|--shared] <id>...   print the wt.exe command per id
```

- `--dry-run` without `--fork` or `--shared` behaves like `--shared`: plain `--resume`, no `--fork-session`.
- `--dry-run` with an id that has no top-level transcript prints nothing on stdout, an error on stderr, and exits 1.
  Other ids in the same call are not printed either; the whole call fails.

## Data sources

- Transcripts: `$HOME/.claude/projects/<slug>/<sessionId>.jsonl`.
  Only top-level files count; `<slug>/<sessionId>/subagents/*.jsonl` and other subdirectories are ignored.
- Registry: `$HOME/.claude/sessions/<pid>.json`, for example `{"pid":15459,"sessionId":"...","cwd":"...","name":"fa-16",...}`.
  Only `*.json` files are read; other files in that folder, such as `*.key`, are ignored.
- A session is running when some registry file has its `sessionId` and `kill -0 <pid>` succeeds.
- Registry name: taken from the live registry file if there is one, otherwise from the registry file with the highest `updatedAt`.
  A stale registry file still supplies the name.
  The name is used only when `nameSource` is not `"derived"`; a missing `nameSource` counts as not derived.
- Transcript titles: `{"type":"custom-title","customTitle":"..."}` lines are set by the user; `{"type":"ai-title","aiTitle":"..."}` lines are generated.
  When a transcript has several lines of one kind, the last one in the file wins.

## Real user prompt

A transcript line is a real user prompt when all of these hold.
The rules come from reading real transcripts under `~/.claude/projects/`.

1. `.type == "user"` and `.isMeta != true`.
2. Text = `.message.content` when it is a string.
   When it is an array, text = all `{"type":"text"}` blocks joined; an array with no text block is not a prompt.
   This drops `tool_result`-only lines.
3. Text does not start with `<` (drops `<command-name>`, `<local-command-stdout>`, `<local-command-caveat>`).
4. Text does not start with `[Request interrupted` (drops the interrupt markers).

A session with zero real prompts is skipped.

## `--list` format

One line per session, fields separated by TAB, sorted by file mtime, newest first:

```text
<sessionId>\t<mtime_epoch_seconds>\t<running 0|1>\t<cwd>\t<label>
```

- `sessionId`: file basename without `.jsonl`.
- `cwd`: `.cwd` of the first line that has one.
- `label`: the first of these that exists.
  1. The last `customTitle` in the transcript.
  2. The last `aiTitle` in the transcript.
  3. The registry name, only when its `nameSource` is not `"derived"`.
  4. The first real prompt.
- Every label source gets the same normalization.
  Runs of newline, tab and carriage return become one space, then the text is cut to the first 60 characters, counted as Unicode characters, not bytes.
  No ellipsis is added.
- `cwd` and `label` are printed raw; `;` is not escaped in `--list`.
- The current-session marker is not part of `--list`; it is only shown in the picker.

## `--dry-run` format

One line per id, in argument order.
Each word is printed with bash `printf '%q'` and words are joined by one space, so the line can be pasted into a shell.

```text
wt.exe -w 0 new-tab --title fix\ the\ login\ bug wsl.exe -d Debian --cd /work/alpha -- bash -lc exec\ claude\ --resume\ <id>\ --fork-session
wt.exe -w 0 new-tab --title Refactor\ the\ payment\ module\ so wsl.exe -d Debian --cd /work/my\ proj -- bash -lc exec\ claude\ --resume\ <id>
wt.exe -w 0 new-tab --title build\\\;deploy wsl.exe -d Debian --cd /work/a\\\;b -- bash -lc exec\ claude\ --resume\ <id>
```

- Title: the `--list` label, cut to its first 30 characters.
- `wt.exe` treats `;` as a command separator.
  So every `;` in the title and the cwd becomes `\;` in the argv word, before `printf '%q'` quotes it.
  The cwd `/work/a;b` becomes the argv word `/work/a\;b`, printed as `/work/a\\\;b`.
- Real mode runs the same argv array with `wt.exe` instead of printing it.

## Parsing approach

`jq` is installed (`/usr/bin/jq`), so use it; no python.
Measured on this machine: 24 transcripts, 39 MB, `grep '"type":"user"' | jq` over all of them takes 0.36 s.

- Pre-filter each file with `grep -hE '"type":"(user|custom-title|ai-title)"'` before `jq`, because transcripts are mostly assistant and API lines.
- Use `jq` string slicing `.[0:60]` for truncation, because jq slices by codepoint.
- Read all registry files with one `jq -s` call, then check each pid with `kill -0`.
- Sort with `find ... -maxdepth 1 -name '*.jsonl' -printf '%T@ %p\n' | sort -rn`, truncating mtime to whole seconds.

## Interactive mode

- Feed `--list` output into `fzf --multi --delimiter '\t' --with-nth` on display columns.
  Display: local time from mtime, cwd with `$HOME` shortened to `~`, label.
  Running rows get a `●` prefix and a color; the row whose id equals `$CLAUDE_SESSION_ID` gets a "current" marker.
- Preview: `cc-restore --preview <id>` prints the last 5 real prompts of that session.
  This is an internal flag for fzf and is not covered by automated tests.
- After selection, for each running session ask `<label>: [F]ork / [s]hared?`; Enter means fork.
  Non-running sessions resume without a question and without `--fork-session`.
- Then run the `wt.exe` argv for each selection.

## Skill file

The skill lives in `skill/restore/SKILL.md` and runs `cc-restore --tab`, which opens the picker in a new tab with the configured profile and the current distro.

## Implementation slices

Each slice turns named tests green; run `bash test/run.sh` after each.

1. Arg parsing and `--list` skeleton: list top-level transcripts newest first with id and mtime.
   Turns green: `list: exit 0`, part of `list: ids newest first` once slices 2 and 3 land.
2. Real-prompt filter, empty-session skip, first-prompt label with 60-character cut.
   Turns green: `tool_result skipped ...`, `label truncated by characters ...`, `ids newest first`.
3. Registry: running flag, and registry name only when not derived.
   Turns green: `running=1 ...`, `running=0 ...`, `non-derived registry name ...`.
4. Transcript titles: `customTitle`, then `aiTitle`, ahead of the registry name.
   Turns green: `latest customTitle ...`, `latest aiTitle ...`, `';' kept raw ...`, `full output, newest first`.
5. `--dry-run` with `--fork`, `--shared`, default, multiple ids, unknown id, 30-character title, `;` escaping.
   Turns green: all `dry-run` tests.
6. Interactive picker, preview, fork or shared question, real `wt.exe` launch.
   Manual checks only, see below.
7. Symlink to `~/.local/bin/cc-restore` and write the skill file.

## Manual end-to-end checklist

1. In a WSL shell, run `cc-restore`.
   Sessions from several project folders appear, newest first, with readable times, `~`-shortened paths and labels.
2. A session open in another tab shows the `●` marker and color.
   Run `cc-restore` from inside a Claude Code session and confirm the current session is marked.
3. Move over rows and confirm the preview shows the last prompts, including Vietnamese text without broken characters.
4. Select one stopped session and press Enter.
   A new tab opens in the same window, titled with the first 30 characters of the label, in the right folder, and the conversation resumes.
5. Select a running session, answer Enter (fork).
   The new tab gets a new session id and the original tab keeps working.
6. Select a running session, answer `s`.
   The new tab resumes the same session id.
7. Select three sessions with Tab and confirm three tabs open.
8. Pick a session whose cwd contains a space, and one whose cwd or title contains `;`, and confirm each tab opens in that folder with the full title.
9. Press Esc in fzf and confirm nothing opens and the exit code is 0 or 130, with no error text.
10. In Claude Code, type `/restore`.
    A new tab opens with the picker, and the tab closes after the picker finishes.
