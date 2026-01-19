#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr LOADERS_SCRIPT="$REPO_ROOT/bootstrap/define-loaders.zsh"

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

assert_empty() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset value="$1" context="$2"
  if [[ -n "$value" ]]; then
    print -u2 -r -- "Expected empty output"
    print -u2 -r -- "Context: $context"
    print -u2 -r -- "Output:"
    print -u2 -r -- "$value"
    return 1
  fi
  return 0
}

typeset tmp_dir=''
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t zsh-kit-define-loaders-test.XXXXXX)" || fail "mktemp failed"

{
  [[ -f "$LOADERS_SCRIPT" ]] || fail "missing loader script: $LOADERS_SCRIPT"
  source "$LOADERS_SCRIPT"
  (( $+functions[source_file] )) || fail "source_file not defined after sourcing $LOADERS_SCRIPT"

  typeset script="$tmp_dir/fixture.zsh"
  {
    print -r -- 'typeset -g ZSH_KIT_TEST_LOADER_FIXTURE_LOADED=1'
    print -r -- 'return 0'
  } >| "$script" || fail "failed to write fixture: $script"

  typeset out_file="$tmp_dir/out.txt" out=''

  ZSH_KIT_TEST_LOADER_FIXTURE_LOADED=0
  ZSH_DEBUG=0 source_file "$script" "fixture" >| "$out_file" 2>&1 || fail "source_file should succeed at ZSH_DEBUG=0"
  out="$(<"$out_file")"
  assert_empty "$out" "ZSH_DEBUG=0 should not print timing output" || fail
  [[ "${ZSH_KIT_TEST_LOADER_FIXTURE_LOADED}" == "1" ]] || fail "fixture script should be sourced at ZSH_DEBUG=0"

  ZSH_KIT_TEST_LOADER_FIXTURE_LOADED=0
  ZSH_DEBUG=1 source_file "$script" "fixture" >| "$out_file" 2>&1 || fail "source_file should succeed at ZSH_DEBUG=1"
  out="$(<"$out_file")"
  assert_contains "$out" "✅ Loaded fixture in " "ZSH_DEBUG=1 should print Loaded timing" || fail "$out"
  assert_not_contains "$out" "🔍 Loading:" "ZSH_DEBUG=1 should not print Loading path" || fail "$out"
  [[ "${ZSH_KIT_TEST_LOADER_FIXTURE_LOADED}" == "1" ]] || fail "fixture script should be sourced at ZSH_DEBUG=1"

  ZSH_KIT_TEST_LOADER_FIXTURE_LOADED=0
  ZSH_DEBUG=2 source_file "$script" "fixture" >| "$out_file" 2>&1 || fail "source_file should succeed at ZSH_DEBUG=2"
  out="$(<"$out_file")"
  assert_contains "$out" "🔍 Loading:" "ZSH_DEBUG=2 should print Loading path" || fail "$out"
  assert_contains "$out" "✅ Loaded fixture in " "ZSH_DEBUG=2 should print Loaded timing" || fail "$out"
  [[ "${ZSH_KIT_TEST_LOADER_FIXTURE_LOADED}" == "1" ]] || fail "fixture script should be sourced at ZSH_DEBUG=2"
}

