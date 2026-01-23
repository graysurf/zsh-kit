#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"

fail() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -u2 -r -- "FAIL: $*"
  exit 1
}

assert_contains() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset haystack="$1" needle="$2" context="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    print -u2 -r -- "Missing: $needle"
    print -u2 -r -- "Context: $context"
    return 1
  fi
  return 0
}

typeset output=''
output="$(
  cd "$REPO_ROOT" && {
    source "$REPO_ROOT/scripts/git/git-scope.zsh" || exit 1
    _git_scope_collect tracked ./scripts
  }
)" || fail "_git_scope_collect tracked ./scripts failed"

assert_contains \
  "$output" \
  $'-\tscripts/git/git-scope.zsh' \
  "tracked ./scripts should include scripts/git/git-scope.zsh" \
  || fail "prefix ./scripts did not match tracked files"

print -r -- "OK"
