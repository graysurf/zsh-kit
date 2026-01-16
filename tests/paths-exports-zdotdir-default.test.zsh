#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr EXPORTS_SCRIPT="$REPO_ROOT/scripts/_internal/paths.exports.zsh"
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

[[ -f "$EXPORTS_SCRIPT" ]] || fail "missing script: $EXPORTS_SCRIPT"

typeset tmp_home=''
tmp_home="$(mktemp -d 2>/dev/null || mktemp -d -t paths-exports-test.XXXXXX)" || fail "mktemp failed"

{
  typeset expected_zdotdir="$tmp_home/.config/zsh"
  typeset expected_cache_dir="$expected_zdotdir/cache"
  typeset expected_histfile="$expected_cache_dir/.zsh_history"

  typeset output='' rc=0
  output="$("$ZSH_BIN" -f -c '
    unset ZDOTDIR \
      ZSH_CONFIG_DIR \
      ZSH_BOOTSTRAP_SCRIPT_DIR \
      ZSH_SCRIPT_DIR \
      ZSH_TOOLS_DIR \
      ZSH_CACHE_DIR \
      ZSH_COMPDUMP \
      HISTFILE
    HOME="$1"
    source "$2"
    print -r -- "$ZDOTDIR"
    print -r -- "$ZSH_CACHE_DIR"
    print -r -- "$HISTFILE"
  ' zsh "$tmp_home" "$EXPORTS_SCRIPT" 2>&1)"
  rc=$?
  assert_eq 0 "$rc" "sourcing paths.exports should exit 0" || fail "$output"

  typeset -a lines=("${(@f)output}")
  if (( ${#lines[@]} < 3 )); then
    fail "unexpected output (expected 3 lines): $output"
  fi

  assert_eq "$expected_zdotdir" "${lines[1]}" "ZDOTDIR should default to HOME/.config/zsh" || fail "$output"
  assert_eq "$expected_cache_dir" "${lines[2]}" "ZSH_CACHE_DIR should default under ZDOTDIR" || fail "$output"
  assert_eq "$expected_histfile" "${lines[3]}" "HISTFILE should default under cache dir" || fail "$output"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_home"
}
