#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr HOOK_SCRIPT="$REPO_ROOT/bootstrap/zsh-kit-setup.zsh"
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
}

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t zsh-kit-setup-test.XXXXXX)" || fail "mktemp failed"

{
  [[ -f "$HOOK_SCRIPT" ]] || fail "hook missing: $HOOK_SCRIPT"

  typeset output='' rc=0
  output="$(
    HOME="$tmp_dir/home" \
      ZDOTDIR="$tmp_dir/not-zdotdir" \
      "$ZSH_BIN" -f -- "$HOOK_SCRIPT" \
        --features 'docker, opencode,docker' \
        --install-tools skip \
        --dry-run \
        2>&1
  )"
  rc=$?
  assert_eq 0 "$rc" "dry-run hook should pass" || fail "$output"
  assert_contains "$output" "features=docker,opencode" "features should normalize and dedupe" || fail "$output"
  assert_contains "$output" "install-tools skipped" "skip policy should not run installer" || fail "$output"
  [[ ! -e "$tmp_dir/home/.zshenv" ]] || fail "dry-run hook must not create home .zshenv"

  output="$(
    HOME="$tmp_dir/home" \
      "$ZSH_BIN" -f -- "$HOOK_SCRIPT" \
        --features 'bad/value' \
        --install-tools skip \
        --dry-run \
        2>&1
  )"
  rc=$?
  assert_eq 2 "$rc" "invalid feature should fail with usage status" || fail "$output"
  assert_contains "$output" "invalid feature name" "invalid feature output" || fail "$output"

  output="$(
    HOME="$tmp_dir/home" \
      "$ZSH_BIN" -f -- "$HOOK_SCRIPT" \
        --features docker \
        --install-tools skip \
        --dry-run \
        --smoke \
        2>&1
  )"
  rc=$?
  assert_eq 0 "$rc" "smoke hook should pass" || fail "$output"
  assert_contains "$output" "running smoke validation" "smoke output" || fail "$output"

  print -r -- "OK"
} always {
  rm -rf -- "$tmp_dir"
}
