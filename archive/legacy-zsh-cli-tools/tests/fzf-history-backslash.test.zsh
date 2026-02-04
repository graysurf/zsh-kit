#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr ZSH_BIN="$(command -v zsh)"

fail() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -u2 -r -- "FAIL: $*"
  exit 1
}

assert_eq() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset expected="$1" actual="$2" context="$3"
  if [[ "$actual" != "$expected" ]]; then
    print -u2 -r -- "Expected: $expected"
    print -u2 -r -- "Actual  : $actual"
    print -u2 -r -- "Context : $context"
    return 1
  fi
  return 0
}

{
  [[ -n "$ZSH_BIN" && -x "$ZSH_BIN" ]] || fail "missing zsh binary"

  typeset tmp_root=''
  tmp_root="$(mktemp -d 2>/dev/null || mktemp -d -t fzf-history-backslash-test.XXXXXX)" || fail "mktemp failed"
  trap 'rm -rf -- "$tmp_root" 2>/dev/null || true' EXIT

  typeset stub_bin="$tmp_root/bin"
  mkdir -p -- "$stub_bin" || fail "mkdir failed"

  cat >| "$stub_bin/fzf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

selection="$(cat | head -n 1)"
printf "enter\n%s\n" "$selection"
EOF
  chmod +x "$stub_bin/fzf" || fail "chmod failed (fzf)"

  cat >| "$stub_bin/tac" <<'EOF'
#!/usr/bin/env bash
cat
EOF
  chmod +x "$stub_bin/tac" || fail "chmod failed (tac)"

  typeset histfile="$tmp_root/history"
  cat >| "$histfile" <<'EOF'
: 1710000000:0;print -r -- foo\ bar
EOF

  typeset output='' rc=0
  output="$(
    cd "$REPO_ROOT" && PATH="$stub_bin:$PATH" HISTFILE="$histfile" "$ZSH_BIN" -f -i -c '
      setopt pipe_fail nounset
      source bootstrap/00-preload.zsh
      source scripts/fzf-tools.zsh
      fzf-history
    ' 2>&1
  )"
  rc=$?

  assert_eq 0 "$rc" "fzf-history should succeed" || fail "$output"
  output="${output//$'\r'/}"
  assert_eq "foo bar" "$output" "should preserve backslash-escaped spaces" || fail "$output"

  print -r -- "OK"
}

