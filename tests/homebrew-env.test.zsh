#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_DIR="${SCRIPT_PATH:h}"
typeset -gr REPO_ROOT="${TEST_DIR:h}"
typeset -gr HOMEBREW_HELPER="$REPO_ROOT/scripts/_internal/homebrew.zsh"

fail() {
  emulate -L zsh
  print -u2 -r -- "FAIL: $*"
  exit 1
}

typeset test_root="${TMPDIR:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh-kit-tests}"
mkdir -p -- "$test_root"
typeset work_dir=''
work_dir="$(mktemp -d "$test_root/homebrew-env.XXXXXX")" || fail "mktemp failed"

{
  typeset homebrew_prefix="$work_dir/homebrew"
  typeset homebrew_bin="$homebrew_prefix/bin"
  typeset homebrew_sbin="$homebrew_prefix/sbin"
  typeset private_bin="$work_dir/private-bin"
  mkdir -p -- "$homebrew_bin" "$homebrew_sbin" "$private_bin"
  : > "$homebrew_bin/brew"
  chmod +x -- "$homebrew_bin/brew"

  source "$HOMEBREW_HELPER"

  path=("$private_bin" "$homebrew_bin" "$homebrew_sbin" /usr/bin)
  zsh_brew::apply_env "$homebrew_bin/brew" || fail "apply_env rejected a valid brew path"
  [[ "${path[1]}" == "$private_bin" ]] \
    || fail "apply_env moved Homebrew ahead of an existing managed PATH prefix: ${(j.:.)path}"
  [[ "${path[2]}" == "$homebrew_bin" && "${path[3]}" == "$homebrew_sbin" ]] \
    || fail "apply_env changed existing Homebrew bin/sbin order: ${(j.:.)path}"

  path=("$private_bin" /usr/bin)
  zsh_brew::apply_env "$homebrew_bin/brew" || fail "apply_env failed to add missing Homebrew paths"
  [[ "${path[1]}" == "$homebrew_bin" && "${path[2]}" == "$homebrew_sbin" ]] \
    || fail "apply_env did not prepend missing Homebrew paths: ${(j.:.)path}"
  [[ "$HOMEBREW_PREFIX" == "$homebrew_prefix" ]] \
    || fail "apply_env did not export HOMEBREW_PREFIX"

  print -r -- "homebrew-env: ok"
} always {
  rm -rf -- "$work_dir"
}
