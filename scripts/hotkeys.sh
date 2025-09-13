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
🌿 git-branch:    Browse and checkout branches interactively
🏷️ git-tag:       Browse and checkout git tags interactively
🌱 env:           Browse environment variables
🔗 alias:         Browse shell aliases
🔧 functions:     Browse defined shell functions
📦 defs:          Browse all definitions (env, alias, functions)
🧪 process:       Browse and kill running processes
🔌 ports:         Browse listening ports and owners
📜 history:       Search and execute command history
📁 directory:     Search directories and cd into selection
📝 file:          Search and preview text files
🧠 vscode:        Search and preview text files in VSCode
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
# Bind `fzf-tools defs` to Ctrl+T
# ────────────────────────────────────────────────────────

fzf-tools-defs-widget() {
  BUFFER="fzf-tools defs $BUFFER"
  CURSOR=${#BUFFER}
  zle accept-line
}

zle -N fzf-tools-defs-widget
bindkey '^T' fzf-tools-defs-widget

# ────────────────────────────────────────────────────────
# Bind `fzf-tools git-commit` to Ctrl+G
# ────────────────────────────────────────────────────────

fzf-tools-git-commit-widget() {
  BUFFER="fzf-tools git-commit $BUFFER"
  CURSOR=${#BUFFER}
  zle accept-line
}

zle -N fzf-tools-git-commit-widget
bindkey '^G' fzf-tools-git-commit-widget

# ────────────────────────────────────────────────────────
# Interactive command history search using fzf
# - Pure insert (no execution)
# - Bound to Ctrl+R via ZLE
# ────────────────────────────────────────────────────────

fzf-history-widget() {
  local selected output cmd

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
}

# Register ZLE widget and bind to Ctrl+R
zle -N fzf-history-widget
bindkey '^R' fzf-history-widget
