# ────────────────────────────────────────────────────────
# Interactive launcher for `fzf-tools`
# - Bound to Ctrl+F
# - Presents categorized, emoji-enhanced command list via `fzf`
# - Inserts selected subcommand into shell prompt
# ────────────────────────────────────────────────────────

fzf-tools-launcher-widget() {
  typeset raw selected subcommand

  raw=$(cat <<EOF | fzf --ansi \
    --prompt="🔧 fzf-tools > " \
    --height=50% \
    --reverse \
    --tiebreak=begin,length
🔍 git-commit:    Browse commits and open changed files in VSCode
📂 git-status:    Interactive git status viewer
🌀 git-checkout:  Pick and checkout a previous commit
🌱 env:           Browse environment variables
🔗 alias:         Browse shell aliases
🔧 functions:     Browse defined shell functions
📦 defs:          Browse all definitions (env, alias, functions)
🧪 process:       Browse and kill running processes
📜 history:       Search and execute command history
📝 file:          Search and preview text files
🧠 vscode:        Search and preview text files in VSCode
📄 fdf:           Search files and open with \$EDITOR
📁 fdd:           Search directories and cd into selection
EOF
  ) || return

  # Extract the part before the colon (includes emoji and command)
  selected="${raw%%:*}"
  # Remove the leading emoji to get the actual command (split by space)
  subcommand="${selected#* }"

  BUFFER="fzf-tools $subcommand"
  CURSOR=${#BUFFER}
  zle accept-line
}

# Register ZLE widget and bind to Ctrl+F
zle -N fzf-tools-launcher-widget
bindkey '^F' fzf-tools-launcher-widget


# ────────────────────────────────────────────────────────
# Interactive command history search using fzf
# - Pure insert (no execution)
# - Bound to Ctrl+R via ZLE
# ────────────────────────────────────────────────────────

# Extract command history and strip line numbers
fzf-history-select() {
  typeset history_output
  if [[ -n "$ZSH_NAME" ]]; then
    history_output=$(fc -l 1)
  else
    history_output=$(history)
  fi

  echo "$history_output" |
    fzf +s --tac |                             # Reverse order (most recent top)
    sed -E 's/ *[0-9]*\*? *//' |               # Remove history number and markers
    sed -E 's/\\/\\\\/g'                       # Escape backslashes for Zsh compatibility
}

# Widget to insert selected command into prompt without executing
fzf-history-widget() {
  local selected="$(fzf-history-select)"
  if [[ -n "$selected" ]]; then
    BUFFER="$selected"
    CURSOR=${#BUFFER}
  fi
}

# Register ZLE widget and bind to Ctrl+R
zle -N fzf-history-widget
bindkey '^R' fzf-history-widget
