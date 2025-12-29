#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr AUDIT_SCRIPT="$REPO_ROOT/tools/audit-fzf-def-docblocks.zsh"

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

typeset ok_dir="$REPO_ROOT/tests/fixtures/audit-fzf-def-docblocks/ok"
typeset gaps_dir="$REPO_ROOT/tests/fixtures/audit-fzf-def-docblocks/gaps"

typeset output='' rc=0

output="$(zsh -f -- "$AUDIT_SCRIPT" --check --stdout "$ok_dir" 2>&1)"
rc=$?
assert_eq 0 "$rc" "ok fixtures should pass" || fail "$output"
assert_contains "$output" "## Gaps (missing docblocks)" "ok fixtures should print gaps section" || fail "$output"
assert_contains "$output" "(none)" "ok fixtures should have no gaps" || fail "$output"

output="$(zsh -f -- "$AUDIT_SCRIPT" --check --stdout "$gaps_dir" 2>&1)"
rc=$?
assert_eq 1 "$rc" "gaps fixtures should fail with --check" || fail "$output"

assert_contains "$output" "fn: gap-missing-fn" "should report missing function docblock" || fail "$output"
assert_contains "$output" "fn: gap_missing_fn2" "should report missing function docblock (function syntax)" || fail "$output"
assert_contains "$output" "fn: gap-blank-line" "should treat blank line as docblock break" || fail "$output"
assert_contains "$output" "fn: gap-blank-line2" "should treat blank line as docblock break (function syntax)" || fail "$output"
assert_contains "$output" "alias: gap_alias" "should report missing alias docblock" || fail "$output"
assert_contains "$output" "alias: GAPG" "should report missing global alias docblock" || fail "$output"

print -r -- "OK"
