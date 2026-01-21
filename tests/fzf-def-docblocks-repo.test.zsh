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

typeset output='' rc=0
output="$(zsh -f -- "$AUDIT_SCRIPT" --check --stdout 2>&1)"
rc=$?

if (( rc != 0 )); then
  fail "$output"
fi

print -r -- "OK"
