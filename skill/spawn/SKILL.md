---
name: spawn
description: Open another interactive Claude Code session in a new Windows Terminal tab on your own, with no user approval. Use to start a new session in a directory (optionally with a first prompt) or to reopen a closed or running session by id. Use when the user asks to open, spawn, start, reopen or resume another session, or when parallel work belongs in its own session.
---

Run `cc-restore` with the Bash tool. Do not ask the user first.

- New session: `cc-restore --new <cwd> ["first prompt"]`
- Reopen by id: `cc-restore --open <id>...`. A running session opens as a fork; add `--shared` to share its id.
- New directory: `cc-restore --trust <dir>` first, so the tab does not stop at Claude's folder-trust prompt. Only for a directory the user named or clearly asked for; never to get around a refusal.
- Find an id: `cc-restore --list | grep -i <text>`. Columns: id, mtime, running, cwd, label.

The command exits 1 with a message when the directory or id is missing, or when `CC_RESTORE_MAX` (default 8) sessions already run. Report that to the user.
Do not use the picker (`cc-restore`, `cc-restore --tab`); that is `/restore`, for the user.
