#!/usr/bin/env -S zsh -f

setopt pipe_fail nounset extendedglob null_glob

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr TEST_ROOT="${SCRIPT_PATH:h}"

# Tests should never open VS Code windows (workspace launcher supports auto-open).
typeset -gx CODEX_WORKSPACE_OPEN_VSCODE_ENABLED=false
unset CODEX_WORKSPACE_OPEN_VSCODE 2>/dev/null || true

typeset -i failed=0
typeset file=''

for file in "$TEST_ROOT"/*.test.zsh(.N); do
  print -r -- "==> $file"
  if ! zsh -f -- "$file"; then
    print -u2 -r -- "FAIL: $file"
    failed=1
  fi
done

if (( failed )); then
  print -u2 -r -- "Some tests failed."
  exit 1
fi

print -r -- "All tests passed."
