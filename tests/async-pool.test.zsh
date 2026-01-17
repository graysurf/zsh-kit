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

{
  [[ -n "$ZSH_BIN" && -x "$ZSH_BIN" ]] || fail "missing zsh binary"

  typeset output='' rc=0
  output="$(
    cd "$REPO_ROOT" && "$ZSH_BIN" -f -i -c '
      setopt monitor notify
      source bootstrap/00-preload.zsh
      source scripts/async-pool.zsh

      _w() {
        emulate -L zsh
        setopt localoptions pipe_fail nounset
        sleep 0.02
        print -r -- ok
      }

      async_pool::map --worker _w --jobs 2 --prefix demo --enabled -- a b c
    ' 2>&1
  )"
  rc=$?

  assert_eq 0 "$rc" "async_pool::map should exit 0" || fail "$output"
  assert_contains "$output" $'a\t0\tok' "should include worker output for item a" || fail "$output"
  assert_contains "$output" $'b\t0\tok' "should include worker output for item b" || fail "$output"
  assert_contains "$output" $'c\t0\tok' "should include worker output for item c" || fail "$output"

  if [[ "$output" == *$'\n--\t'* ]]; then
    fail "async_pool::map should not treat '--' as an item"
  fi

  typeset -a lines=()
  lines=("${(@f)output}")

  typeset line=''
  for line in "${lines[@]}"; do
    line="${line//$'\r'/}"
    if [[ "$line" == \[[0-9]##\]* ]]; then
      fail "unexpected job-control output: ${line}"
    fi
  done

  print -r -- "OK"
}

