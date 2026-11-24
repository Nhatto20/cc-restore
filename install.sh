#!/usr/bin/env bash
# Link cc-restore into ~/.local/bin, the restore and spawn skills into ~/.claude/skills, and allow the command. Safe to re-run.
set -euo pipefail

repo=$(cd "$(dirname "$0")" && pwd)
bin=$HOME/.local/bin
skills=${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills

missing=()
for cmd in jq fzf wt.exe wsl.exe claude; do
  command -v "$cmd" >/dev/null || missing+=("$cmd")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "Missing: ${missing[*]}" >&2
  echo "Install jq and fzf with: sudo apt install jq fzf" >&2
  echo "wt.exe and wsl.exe come from Windows; claude from https://claude.com/claude-code" >&2
  exit 1
fi

mkdir -p "$bin" "$skills"
ln -sfn "$repo/cc-restore" "$bin/cc-restore"

# Replace an older copied skill dir; a symlink keeps it in sync with git pull.
if [ -e "$skills/restore" ] && [ ! -L "$skills/restore" ]; then
  mv "$skills/restore" "$skills/restore.bak.$(date +%s)"
fi
ln -sfn "$repo/skill/restore" "$skills/restore"
ln -sfn "$repo/skill/spawn" "$skills/spawn"

# Let Claude run cc-restore without an approval prompt (the spawn skill needs it).
settings=${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json
[ -f "$settings" ] || echo '{}' >"$settings"
tmp=$(mktemp)
jq 'if (.permissions.allow // [] | index("Bash(cc-restore:*)")) then . else .permissions.allow += ["Bash(cc-restore:*)"] end' "$settings" >"$tmp" \
  || { echo "$settings is not valid JSON; add Bash(cc-restore:*) to permissions.allow by hand" >&2; rm -f "$tmp"; exit 1; }
cat "$tmp" >"$settings"
rm -f "$tmp"

echo "Installed: $bin/cc-restore, $skills/restore, $skills/spawn; allowed Bash(cc-restore:*) in $settings"
case ":$PATH:" in
  *":$bin:"*) ;;
  *) echo "Add $bin to PATH, e.g. in ~/.profile: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac
