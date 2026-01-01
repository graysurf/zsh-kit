# ───────────────────────────────────────────────────────
# Editor config
# ────────────────────────────────────────────────────────

if command -v safe_unalias >/dev/null; then
  safe_unalias vi
fi

export EDITOR="${EDITOR:-nvim}"

# vi: Wrapper for `$EDITOR`.
# Usage: vi [args...]
# Notes:
# - Uses the current $EDITOR at runtime (supports multi-word commands).
vi() {
  emulate -L zsh
  setopt err_return

  if [[ -z "${EDITOR-}" ]]; then
    print -u2 -r -- "❌ EDITOR is not set"
    return 1
  fi

  typeset -a editor_cmd
  editor_cmd=(${(z)EDITOR})
  "${editor_cmd[@]}" "$@"
}

