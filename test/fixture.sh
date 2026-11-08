# Builds a fake $HOME with Claude Code transcripts and session registry.
# Usage: build_fixture <dir> <live_pid> <dead_pid>

ID_A=aaaaaaaa-0000-4000-8000-000000000001 # running, derived registry name ignored, string prompt
ID_B=bbbbbbbb-0000-4000-8000-000000000002 # other project, cwd with space, array prompt, long
ID_C=cccccccc-0000-4000-8000-000000000003 # stale registry (dead pid), derived name ignored
ID_D=dddddddd-0000-4000-8000-000000000004 # no real prompt, newest file, must be excluded
ID_E=eeeeeeee-0000-4000-8000-000000000005 # subagent transcript in subdir, must be excluded
ID_G=99999999-0000-4000-8000-000000000007 # unicode prompt over 60 chars
ID_H=11111111-0000-4000-8000-000000000008 # non-derived registry name, no titles
ID_I=22222222-0000-4000-8000-000000000009 # customTitle and aiTitle, customTitle wins
ID_J=33333333-0000-4000-8000-00000000000a # aiTitle only, derived registry name ignored
ID_K=44444444-0000-4000-8000-00000000000b # ';' in cwd and title

# Registry files use pids <dead>, <dead>+1, <dead>+2; all must be dead.
build_fixture() {
  local h=$1 live=$2 dead=$3
  local p1="$h/.claude/projects/-work-alpha" p2="$h/.claude/projects/-work-my-proj" s="$h/.claude/sessions"
  mkdir -p "$p1" "$p2" "$s" "$p1/$ID_A/subagents"

  # A: metadata lines first, then non-prompts, then the first real prompt.
  cat >"$p1/$ID_A.jsonl" <<EOF
{"type":"permission-mode","permissionMode":"default","sessionId":"$ID_A"}
{"type":"last-prompt","lastPrompt":"fix the login bug","sessionId":"$ID_A"}
{"type":"user","isMeta":true,"cwd":"/work/alpha","sessionId":"$ID_A","message":{"role":"user","content":"<local-command-caveat>Caveat</local-command-caveat>"}}
{"type":"user","cwd":"/work/alpha","sessionId":"$ID_A","message":{"role":"user","content":"<command-name>/model</command-name>"}}
{"type":"user","cwd":"/work/alpha","sessionId":"$ID_A","origin":{"kind":"human"},"message":{"role":"user","content":"fix the login bug"}}
{"type":"assistant","cwd":"/work/alpha","sessionId":"$ID_A","message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Read","input":{}}]}}
{"type":"user","cwd":"/work/alpha","sessionId":"$ID_A","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1","content":"file body"}]}}
{"type":"user","cwd":"/work/alpha","sessionId":"$ID_A","origin":{"kind":"human"},"message":{"role":"user","content":"now add a test"}}
EOF

  # B: first user line is tool_result only; first real prompt is an array text block with a newline.
  cat >"$p2/$ID_B.jsonl" <<EOF
{"type":"user","cwd":"/work/my proj","sessionId":"$ID_B","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t0","content":"ignored tool output"}]}}
{"type":"user","cwd":"/work/my proj","sessionId":"$ID_B","message":{"role":"user","content":[{"type":"text","text":"Refactor the payment module so retries use exponential backoff\nand log every attempt"}]}}
EOF

  cat >"$p1/$ID_C.jsonl" <<EOF
{"type":"user","cwd":"/work/gamma","sessionId":"$ID_C","message":{"role":"user","content":"gamma first prompt"}}
EOF

  # D: only metadata, meta, command, interrupt marker and tool_result lines.
  cat >"$p1/$ID_D.jsonl" <<EOF
{"type":"permission-mode","permissionMode":"default","sessionId":"$ID_D"}
{"type":"user","isMeta":true,"cwd":"/work/delta","sessionId":"$ID_D","message":{"role":"user","content":[{"type":"text","text":"# Some Skill body"}]}}
{"type":"user","cwd":"/work/delta","sessionId":"$ID_D","message":{"role":"user","content":"<command-name>/clear</command-name>"}}
{"type":"user","cwd":"/work/delta","sessionId":"$ID_D","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}
{"type":"user","cwd":"/work/delta","sessionId":"$ID_D","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t9","content":"x"}]}}
EOF

  cat >"$p1/$ID_A/subagents/$ID_E.jsonl" <<EOF
{"type":"user","cwd":"/work/alpha","sessionId":"$ID_E","message":{"role":"user","content":"subagent task prompt"}}
EOF

  # G: 70 x U+0111 (2 bytes each in UTF-8).
  local seventy
  seventy=$(printf 'đ%.0s' {1..70})
  cat >"$p2/$ID_G.jsonl" <<EOF
{"type":"user","cwd":"/work/viet","sessionId":"$ID_G","message":{"role":"user","content":"$seventy"}}
EOF

  cat >"$s/$live.json" <<EOF
{"pid":$live,"sessionId":"$ID_A","cwd":"/work/alpha","name":"alpha-1","nameSource":"derived","status":"idle","updatedAt":1767398400000}
EOF
  cat >"$s/$dead.json" <<EOF
{"pid":$dead,"sessionId":"$ID_C","cwd":"/work/gamma","name":"gamma-old","nameSource":"derived","status":"idle","updatedAt":1767225600000}
EOF
  echo "not json" >"$s/3469.0123abcd.key"
  # half-written registry file must not hide the running flag of the others
  printf '{"pid":' >"$s/4194099.json"

  cat >"$p1/$ID_H.jsonl" <<EOF
{"type":"user","cwd":"/work/hotel","sessionId":"$ID_H","message":{"role":"user","content":"hotel first prompt"}}
EOF
  cat >"$s/$((dead + 1)).json" <<EOF
{"pid":$((dead + 1)),"sessionId":"$ID_H","cwd":"/work/hotel","name":"hotel-manual","nameSource":"manual","status":"idle","updatedAt":1767139200000}
EOF

  # I: two customTitle lines (latest wins); an aiTitle written after them must still lose.
  cat >"$p2/$ID_I.jsonl" <<EOF
{"type":"custom-title","customTitle":"old title","sessionId":"$ID_I"}
{"type":"user","cwd":"/work/india","sessionId":"$ID_I","message":{"role":"user","content":"india first prompt"}}
{"type":"custom-title","customTitle":"release-notes","sessionId":"$ID_I"}
{"type":"ai-title","aiTitle":"AI summary title","sessionId":"$ID_I"}
EOF

  cat >"$p2/$ID_J.jsonl" <<EOF
{"type":"ai-title","aiTitle":"first ai","sessionId":"$ID_J"}
{"type":"user","cwd":"/work/juliet","sessionId":"$ID_J","message":{"role":"user","content":"juliet first prompt"}}
{"type":"ai-title","aiTitle":"Fix flaky CI job","sessionId":"$ID_J"}
EOF
  cat >"$s/$((dead + 2)).json" <<EOF
{"pid":$((dead + 2)),"sessionId":"$ID_J","cwd":"/work/juliet","name":"j-derived","nameSource":"derived","status":"idle","updatedAt":1766966400000}
EOF

  cat >"$p1/$ID_K.jsonl" <<EOF
{"type":"custom-title","customTitle":"build;deploy","sessionId":"$ID_K"}
{"type":"user","cwd":"/work/a;b","sessionId":"$ID_K","message":{"role":"user","content":"kilo first prompt"}}
EOF

  touch -d '2025-12-31 00:00:00 UTC' "$p1/$ID_H.jsonl"
  touch -d '2025-12-30 00:00:00 UTC' "$p2/$ID_I.jsonl"
  touch -d '2025-12-29 00:00:00 UTC' "$p2/$ID_J.jsonl"
  touch -d '2025-12-28 00:00:00 UTC' "$p1/$ID_K.jsonl"

  touch -d '2026-01-03 00:00:00 UTC' "$p1/$ID_A.jsonl"
  touch -d '2026-01-02 00:00:00 UTC' "$p2/$ID_B.jsonl"
  touch -d '2026-01-01 12:00:00 UTC' "$p2/$ID_G.jsonl"
  touch -d '2026-01-01 00:00:00 UTC' "$p1/$ID_C.jsonl"
  touch -d '2026-01-04 00:00:00 UTC' "$p1/$ID_D.jsonl"
  touch -d '2026-01-05 00:00:00 UTC' "$p1/$ID_A/subagents/$ID_E.jsonl"
}
