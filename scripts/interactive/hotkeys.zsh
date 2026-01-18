# ────────────────────────────────────────────────────────
# Interactive launcher for `fzf-tools`
# - Bound to Ctrl+F
# - Presents categorized, emoji-enhanced command list via `fzf`
# - Inserts selected subcommand into shell prompt
# ────────────────────────────────────────────────────────

# fzf-tools-launcher-widget
# ZLE widget: pick an `fzf-tools` subcommand via `fzf` and execute it.
# Usage: fzf-tools-launcher-widget
# Notes:
# - Bound to Ctrl+F.
# - Requires an interactive ZLE session and `fzf`.
fzf-tools-launcher-widget() {
  typeset raw='' selected='' subcommand=''

  raw=$(cat <<EOF | fzf --ansi \
    --prompt="🔧 fzf-tools > " \
    --height=50% \
    --reverse \
    --tiebreak=begin,length
🧪 process:       Browse and kill running processes
🔌 port:          Browse listening ports and owners
📜 history:       Search and execute command history
🔍 git-commit:    Browse commits and open changed files
📂 git-status:    Interactive git status viewer
🌀 git-checkout:  Pick and checkout a previous commit
🌿 git-branch:    Browse and checkout branches interactively
🏷️ git-tag:       Browse and checkout git tags interactively
🌱 env:           Browse environment variables
🔗 alias:         Browse shell aliases
🔧 function:      Browse defined shell functions
📦 def:           Browse all definitions (env, alias, functions)
📁 directory:     Search directories and cd into selection
📝 file:          Search and preview text files
EOF
  ) || return

  # Extract the part before the colon (includes emoji and command)
  selected="${raw%%:*}"
  # Remove the leading emoji to get the actual command (split by space)
  subcommand="${selected#* }"

  BUFFER="fzf-tools $subcommand"
  CURSOR=${#BUFFER}
  zle accept-line
  return 0
}

# Register ZLE widget and bind to Ctrl+F
zle -N fzf-tools-launcher-widget
bindkey '^F' fzf-tools-launcher-widget

# ────────────────────────────────────────────────────────
# `fzf-tools file` widget (intentionally unbound)
# ────────────────────────────────────────────────────────

# fzf-tools-file-widget
# ZLE widget: prefix the current buffer with `fzf-tools file` and execute it.
# Usage: fzf-tools-file-widget
# Notes:
# - Intentionally not bound to a hotkey.
fzf-tools-file-widget() {
  BUFFER="fzf-tools file $BUFFER"
  CURSOR=${#BUFFER}
  zle accept-line
  return 0
}

zle -N fzf-tools-file-widget

# ────────────────────────────────────────────────────────
# Bind `fzf-tools def` to Ctrl+T
# ────────────────────────────────────────────────────────

# fzf-tools-def-widget
# ZLE widget: prefix the current buffer with `fzf-tools def` and execute it.
# Usage: fzf-tools-def-widget
# Notes:
# - Bound to Ctrl+T.
fzf-tools-def-widget() {
  BUFFER="fzf-tools def $BUFFER"
  CURSOR=${#BUFFER}
  zle accept-line
  return 0
}

zle -N fzf-tools-def-widget
bindkey '^T' fzf-tools-def-widget

# ────────────────────────────────────────────────────────
# Bind `fzf-tools git-commit` to Ctrl+G
# ────────────────────────────────────────────────────────

# fzf-tools-git-commit-widget
# ZLE widget: prefix the current buffer with `fzf-tools git-commit` and execute it.
# Usage: fzf-tools-git-commit-widget
# Notes:
# - Bound to Ctrl+G.
fzf-tools-git-commit-widget() {
  BUFFER="fzf-tools git-commit $BUFFER"
  CURSOR=${#BUFFER}
  zle accept-line
  return 0
}

zle -N fzf-tools-git-commit-widget
bindkey '^G' fzf-tools-git-commit-widget

# ────────────────────────────────────────────────────────
# Interactive command history search using fzf
# - Pure insert (no execution)
# - Bound to Ctrl+R via ZLE
# ────────────────────────────────────────────────────────

# fzf-history-widget
# ZLE widget: fuzzy-search history and insert the selected command into the buffer.
# Usage: fzf-history-widget
# Notes:
# - Bound to Ctrl+R.
# - Depends on `fzf-history-select` (defined in `scripts/fzf-tools.zsh`).
fzf-history-widget() {
  local selected='' output='' cmd=''

  # fzf returns two lines: 1) key pressed, 2) selected entry
  output="$(fzf-history-select)"
  selected="$(printf "%s\n" "$output" | sed -n '2p')"

  # Extract command column
  cmd="$(printf "%s\n" "$selected" | cut -d'|' -f3- | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"

  # Remove leading emoji (🖥️ or others)
  cmd="$(printf "%s\n" "$cmd" | sed -E 's/^[[:space:]]*(🖥️|🧪|🐧|🐳|🛠️)?[[:space:]]*//')"

  if [[ -n "$cmd" ]]; then
    BUFFER="$cmd"
    CURSOR=${#BUFFER}
  fi
  return 0
}

# Register ZLE widget and bind to Ctrl+R
zle -N fzf-history-widget
bindkey '^R' fzf-history-widget

# ────────────────────────────────────────────────────────
# Codex feature hotkeys (optional)
# ────────────────────────────────────────────────────────

# Bind `codex-rate-limits-async` to Ctrl+U when feature:codex is enabled.
if (( $+functions[codex-rate-limits-async] )); then
  # codex-rate-limits-async-widget
  # ZLE widget: run `codex-rate-limits-async` without clobbering the current buffer.
  codex-rate-limits-async-widget() {
    emulate -L zsh

    local saved_buffer="${BUFFER}"
    local -i saved_cursor="${CURSOR}"
    local -i rc=0

    print -r --
    codex-rate-limits-async
    rc=$?

    BUFFER="${saved_buffer}"
    CURSOR="${saved_cursor}"
    zle reset-prompt
    return $rc
  }

  zle -N codex-rate-limits-async-widget
  bindkey '^U' codex-rate-limits-async-widget
fi
