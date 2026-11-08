---
name: restore
description: Open the cc-restore picker in a new Windows Terminal tab to resume past Claude Code sessions from any project. Use when the user types /restore or asks to restore, reopen or resume old sessions.
---

Run `cc-restore --tab` with the Bash tool, then tell the user the picker opened in a new tab.

Do not run plain `cc-restore` here, because the picker needs an interactive terminal.
