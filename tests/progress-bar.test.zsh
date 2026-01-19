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

assert_contains() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset haystack="$1" needle="$2" context="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    print -u2 -r -- "Missing substring: $needle"
    print -u2 -r -- "Context         : $context"
    return 1
  fi
  return 0
}

assert_not_contains() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset haystack="$1" needle="$2" context="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    print -u2 -r -- "Unexpected substring: $needle"
    print -u2 -r -- "Context            : $context"
    return 1
  fi
  return 0
}

{
  [[ -n "$ZSH_BIN" && -x "$ZSH_BIN" ]] || fail "missing zsh binary"

  typeset output='' rc=0

  output="$(cd "$REPO_ROOT" && LC_ALL=C "$ZSH_BIN" -f -c '
    source bootstrap/00-preload.zsh
    progress_bar::init pb --prefix Test --total 3
    progress_bar::update pb 1
    progress_bar::finish pb
  ' 2>&1)"
  rc=$?
  assert_eq 0 "$rc" "progress bar (default) should exit 0" || fail "$output"
  assert_eq '' "$output" "progress bar should be silent when stderr is not a TTY" || fail "$output"

  output="$(cd "$REPO_ROOT" && LC_ALL=C "$ZSH_BIN" -f -c '
    source bootstrap/00-preload.zsh
    progress_bar::init pb --prefix Test --total 3 --enabled --width 10 --head-len 2 --fd 2
    progress_bar::update pb 1 --suffix one
    progress_bar::finish pb --suffix done
  ' 2>&1)"
  rc=$?
  assert_eq 0 "$rc" "progress bar (--enabled) should exit 0" || fail "$output"
  assert_contains "$output" $'\rTest [' "enabled progress bar should render a single-line update" || fail "$output"
  assert_contains "$output" '1/3' "enabled progress bar should include current/total" || fail "$output"
  assert_contains "$output" '3/3' "enabled progress bar should include final current/total" || fail "$output"

  output="$(cd "$REPO_ROOT" && LC_ALL=C COLUMNS=30 "$ZSH_BIN" -f -c '
    source bootstrap/00-preload.zsh
    progress_bar::init pb --prefix Test --total 3 --enabled --width 10 --head-len 2 --fd 2
    progress_bar::update pb 1 --suffix abcdefghijklmnopqrstuvwxyz
    progress_bar::finish pb --suffix done
  ' 2>&1)"
  rc=$?
  assert_eq 0 "$rc" "progress bar (truncation) should exit 0" || fail "$output"
  assert_not_contains "$output" 'abcdefghijklmnopqrstuvwxyz' "progress bar should truncate long suffix to avoid wrapping" || fail "$output"

  print -r -- "OK"
}
