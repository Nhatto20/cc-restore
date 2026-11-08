#!/usr/bin/env bash
# Plain bash test runner for cc-restore. Exit 0 = all pass, 1 = test failure, 2 = broken setup.
set -u
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TOOL=${CC_RESTORE:-$here/../cc-restore}
source "$here/fixture.sh"

fx=$(mktemp -d)
sleep 300 &
LIVE=$!
DEAD=4194000
trap 'kill $LIVE 2>/dev/null; rm -rf "$fx"' EXIT

kill -0 "$LIVE" 2>/dev/null || { echo "SETUP: live pid $LIVE not alive"; exit 2; }
for p in $DEAD $((DEAD + 1)) $((DEAD + 2)); do
  kill -0 "$p" 2>/dev/null && { echo "SETUP: dead pid $p is alive, pick another DEAD"; exit 2; }
done
[ -x "$TOOL" ] || { echo "SETUP: $TOOL not executable"; exit 2; }
build_fixture "$fx" "$LIVE" "$DEAD"

run() { env -u CLAUDE_SESSION_ID HOME="$fx" TZ=UTC LC_ALL=C.UTF-8 "$TOOL" "$@"; }

pass=0 fail=0
check() { # check <name> <expected> <actual>
  if [ "$2" == "$3" ]; then
    pass=$((pass + 1)); echo "PASS $1"
  else
    fail=$((fail + 1)); echo "FAIL $1"
    diff <(printf '%s\n' "$2") <(printf '%s\n' "$3") | sed 's/^/    /'
  fi
}

T=$'\t'
ROW_A="aaaaaaaa-0000-4000-8000-000000000001${T}1767398400${T}1${T}/work/alpha${T}fix the login bug"
ROW_B="bbbbbbbb-0000-4000-8000-000000000002${T}1767312000${T}0${T}/work/my proj${T}Refactor the payment module so retries use exponential backo"
ROW_G="99999999-0000-4000-8000-000000000007${T}1767268800${T}0${T}/work/viet${T}đđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđđ"
ROW_C="cccccccc-0000-4000-8000-000000000003${T}1767225600${T}0${T}/work/gamma${T}gamma first prompt"
ROW_H="11111111-0000-4000-8000-000000000008${T}1767139200${T}0${T}/work/hotel${T}hotel-manual"
ROW_I="22222222-0000-4000-8000-000000000009${T}1767052800${T}0${T}/work/india${T}release-notes"
ROW_J="33333333-0000-4000-8000-00000000000a${T}1766966400${T}0${T}/work/juliet${T}Fix flaky CI job"
ROW_K="44444444-0000-4000-8000-00000000000b${T}1766880000${T}0${T}/work/a;b${T}build;deploy"

# --- --list ---
out=$(run --list); rc=$?
check "list: exit 0" 0 "$rc"
check "list: full output, newest first" "$ROW_A
$ROW_B
$ROW_G
$ROW_C
$ROW_H
$ROW_I
$ROW_J
$ROW_K" "$out"
check "list: ids newest first" \
  "aaaaaaaa-0000-4000-8000-000000000001 bbbbbbbb-0000-4000-8000-000000000002 99999999-0000-4000-8000-000000000007 cccccccc-0000-4000-8000-000000000003 11111111-0000-4000-8000-000000000008 22222222-0000-4000-8000-000000000009 33333333-0000-4000-8000-00000000000a 44444444-0000-4000-8000-00000000000b" \
  "$(cut -f1 <<<"$out" | paste -sd' ')"
check "list: subagent subdir transcript excluded" "" "$(grep eeeeeeee <<<"$out")"
check "list: session with no real prompt excluded" "" "$(grep dddddddd <<<"$out")"
check "list: running=1 for live registry pid, derived registry name ignored" "$ROW_A" "$(grep '^aaaaaaaa' <<<"$out")"
check "list: running=0 for stale registry, derived name ignored" "$ROW_C" "$(grep '^cccccccc' <<<"$out")"
check "list: tool_result skipped, label=first prompt cut to 60 chars, newline to space" "$ROW_B" "$(grep '^bbbbbbbb' <<<"$out")"
check "list: label truncated by characters, not bytes" "$ROW_G" "$(grep '^99999999' <<<"$out")"
check "list: non-derived registry name beats first prompt" "$ROW_H" "$(grep '^11111111' <<<"$out")"
check "list: latest customTitle beats aiTitle" "$ROW_I" "$(grep '^22222222' <<<"$out")"
check "list: latest aiTitle beats derived registry name" "$ROW_J" "$(grep '^33333333' <<<"$out")"
check "list: ';' kept raw in cwd and label" "$ROW_K" "$(grep '^44444444' <<<"$out")"

# --- --dry-run ---
unset CC_RESTORE_PROFILE
export WSL_DISTRO_NAME=Debian
WT='wt.exe -w 0 new-tab -p Windows\ PowerShell --title'
out=$(run --dry-run --fork aaaaaaaa-0000-4000-8000-000000000001); rc=$?
check "dry-run --fork: exit 0" 0 "$rc"
check "dry-run --fork: title=label, --fork-session" \
  "$WT fix\\ the\\ login\\ bug wsl.exe -d Debian --cd /work/alpha -- bash -lc exec\\ claude\\ --resume\\ aaaaaaaa-0000-4000-8000-000000000001\\ --fork-session" "$out"

out=$(run --dry-run --shared bbbbbbbb-0000-4000-8000-000000000002)
check "dry-run --shared: title=label cut to 30 chars, quoted space, no --fork-session" \
  "$WT Refactor\\ the\\ payment\\ module\\ so wsl.exe -d Debian --cd /work/my\\ proj -- bash -lc exec\\ claude\\ --resume\\ bbbbbbbb-0000-4000-8000-000000000002" "$out"

out=$(run --dry-run cccccccc-0000-4000-8000-000000000003)
check "dry-run default: plain resume" \
  "$WT gamma\\ first\\ prompt wsl.exe -d Debian --cd /work/gamma -- bash -lc exec\\ claude\\ --resume\\ cccccccc-0000-4000-8000-000000000003" "$out"

out=$(run --dry-run --fork cccccccc-0000-4000-8000-000000000003 aaaaaaaa-0000-4000-8000-000000000001)
check "dry-run multiple ids: one line each, argument order" \
  "$WT gamma\\ first\\ prompt wsl.exe -d Debian --cd /work/gamma -- bash -lc exec\\ claude\\ --resume\\ cccccccc-0000-4000-8000-000000000003\\ --fork-session
$WT fix\\ the\\ login\\ bug wsl.exe -d Debian --cd /work/alpha -- bash -lc exec\\ claude\\ --resume\\ aaaaaaaa-0000-4000-8000-000000000001\\ --fork-session" "$out"

out=$(run --dry-run --shared 44444444-0000-4000-8000-00000000000b)
check "dry-run: ';' escaped as \\; in title and cwd" \
  "$WT build\\\\\\;deploy wsl.exe -d Debian --cd /work/a\\\\\\;b -- bash -lc exec\\ claude\\ --resume\\ 44444444-0000-4000-8000-00000000000b" "$out"

out=$(CC_RESTORE_PROFILE=Debian run --dry-run cccccccc-0000-4000-8000-000000000003)
check "dry-run: CC_RESTORE_PROFILE picks the WT profile" \
  "wt.exe -w 0 new-tab -p Debian --title gamma\\ first\\ prompt wsl.exe -d Debian --cd /work/gamma -- bash -lc exec\\ claude\\ --resume\\ cccccccc-0000-4000-8000-000000000003" "$out"

out=$(WSL_DISTRO_NAME=Ubuntu-24.04 run --dry-run cccccccc-0000-4000-8000-000000000003)
check "dry-run: tab opens in the current WSL distro" \
  "$WT gamma\\ first\\ prompt wsl.exe -d Ubuntu-24.04 --cd /work/gamma -- bash -lc exec\\ claude\\ --resume\\ cccccccc-0000-4000-8000-000000000003" "$out"

out=$(CC_RESTORE_PROFILE= run --dry-run cccccccc-0000-4000-8000-000000000003)
check "dry-run: empty CC_RESTORE_PROFILE omits -p" \
  "wt.exe -w 0 new-tab --title gamma\\ first\\ prompt wsl.exe -d Debian --cd /work/gamma -- bash -lc exec\\ claude\\ --resume\\ cccccccc-0000-4000-8000-000000000003" "$out"

out=$(run --dry-run ffffffff-0000-4000-8000-00000000000f 2>/dev/null); rc=$?
check "dry-run unknown id: nonzero exit" 1 "$([ "$rc" -ne 0 ] && echo 1 || echo 0)"
check "dry-run unknown id: nothing on stdout" "" "$out"

echo "---"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
