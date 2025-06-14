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
# Bind `fzf-tools defs` to Ctrl+T
# ────────────────────────────────────────────────────────

fzf-tools-defs-widget() {
  BUFFER="fzf-tools defs"
  CURSOR=${#BUFFER}
  zle accept-line
}

zle -N fzf-tools-defs-widget
bindkey '^T' fzf-tools-defs-widget

# ────────────────────────────────────────────────────────
# Bind `fzf-tools git-commit` to Ctrl+G
# ────────────────────────────────────────────────────────

fzf-tools-git-commit-widget() {
  BUFFER="fzf-tools git-commit"
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

# Extract command history and strip line numbers
fzf-history-select() {
  local default_query="${BUFFER:-}"

  iconv -f utf-8 -t utf-8 -c "$HISTFILE" |
  awk -F';' '
    /^:/ {
      if (NF < 2) next
      split($1, meta, ":")
      cmd = $2

      if (cmd ~ /^[[:space:]]*$/) next
      if (cmd ~ /^[[:cntrl:][:punct:][:space:]]*$/) next
      if (cmd ~ /[^[:print:]]/) next

      ts_cmd = "date -r " meta[2] " +\"%Y-%m-%d %H:%M:%S\""
      ts_cmd | getline ts
      close(ts_cmd)

      gsub(/\\/, "\\\\", cmd)
      printf "🕐 %s | %4d | 🖥️ %s\n", ts, NR, cmd
    }
  ' | fzf --ansi --reverse --height=50% \
         --query="$default_query" \
         --preview-window='right:40%:wrap' \
         --preview='ts=$(cut -d"|" -f1 <<< {} | sed "s/[[:space:]]*$//"); cmd=$(cut -d"|" -f3- <<< {} | sed -E "s/^[[:space:]]*(🖥️|🧪|🐧|🐳|🛠️)?[[:space:]]*//"); printf "%s\n\n%s" "$ts" "$cmd"' \
         --expect=enter
}

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

