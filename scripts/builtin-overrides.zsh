# ───────────────────────────────────────────────────────
# Builtin overrides (interactive UX)
# ────────────────────────────────────────────────────────
#
# This module intentionally overrides builtins/commands for interactive UX:
# - cd: auto-list directory contents after changing directory
# - cat: prefer bat (plain output; no pager)
# - history: run fzf-history when called with no args
#
# Configure overrides:
# - Enabled by default.
# - Disable by setting:
#   export SHELL_UTILS_BUILTIN_OVERRIDES_ENABLED=false
#
# Notes:
# - Wrappers are designed to be "quiet" in non-interactive contexts.

if command -v safe_unalias >/dev/null; then
  safe_unalias cd cat history
fi

# cd [path]
# Change directory then list contents (eza preferred).
# Usage: cd [path]
# Notes:
# - Builtin override for interactive UX.
cd() {
  emulate -L zsh

  builtin cd "$@" || return

  typeset overrides_enabled='true'
  if (( ${+SHELL_UTILS_BUILTIN_OVERRIDES_ENABLED} )); then
    if zsh_env::is_true "${SHELL_UTILS_BUILTIN_OVERRIDES_ENABLED-}" "SHELL_UTILS_BUILTIN_OVERRIDES_ENABLED"; then
      overrides_enabled='true'
    else
      overrides_enabled='false'
    fi
  fi

  if [[ ! -o interactive || ! -t 1 || "$overrides_enabled" != true ]]; then
    return 0
  fi

  if command -v eza >/dev/null 2>&1; then
    eza -alh --icons --group-directories-first --time-style=iso
  else
    command ls -la
  fi
}

# cat <path...>
# Show files (bat preferred; no pager).
# Usage: cat <path...>
# Notes:
# - Builtin override for interactive UX.
cat() {
  emulate -L zsh

  # Non-interactive shell (scripts) or explicit opt-out: fall back to the real `cat`.
  if [[ ! -o interactive ]]; then
    command cat "$@"
    return $?
  fi

  if (( ${+SHELL_UTILS_BUILTIN_OVERRIDES_ENABLED} )) \
      && ! zsh_env::is_true "${SHELL_UTILS_BUILTIN_OVERRIDES_ENABLED-}" "SHELL_UTILS_BUILTIN_OVERRIDES_ENABLED"; then
    command cat "$@"
    return $?
  fi

  # If stdin or stdout is not a TTY, we're likely in a pipeline / completion preview.
  # `bat` may warn (or behave differently) when reading "binary-looking" content from STDIN,
  # so keep the original `cat` behavior in these cases.
  if [[ ! -t 0 || ! -t 1 ]]; then
    command cat "$@"
    return $?
  fi

  # Interactive UX: prefer `bat` (plain style, no pager) when available.
  if command -v bat >/dev/null 2>&1; then
    bat --style=plain --pager=never "$@"
    return $?
  fi

  # Final fallback.
  command cat "$@"
}

# history [history args...]
# With no args: fzf-history; otherwise: builtin history.
# Usage: history [history args...]
# Notes:
# - Builtin override for interactive UX.
history() {
  emulate -L zsh
  setopt pipe_fail

  if [[ ! -o interactive ]]; then
    builtin history "$@"
    return $?
  fi

  if (( ${+SHELL_UTILS_BUILTIN_OVERRIDES_ENABLED} )) \
      && ! zsh_env::is_true "${SHELL_UTILS_BUILTIN_OVERRIDES_ENABLED-}" "SHELL_UTILS_BUILTIN_OVERRIDES_ENABLED"; then
    builtin history "$@"
    return $?
  fi

  if (( $# == 0 )) && [[ -t 0 && -t 1 ]] && (( $+functions[fzf-history] )); then
    fzf-history
    return $?
  fi

  builtin history "$@"
}
