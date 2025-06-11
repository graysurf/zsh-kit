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
bindkey -r '^T' 
bindkey '^T' fzf-tools-launcher-widget


# ────────────────────────────────────────────────────────
# Interactive command history search using fzf
# - Pure insert (no execution)
# - Bound to Ctrl+R via ZLE
# ────────────────────────────────────────────────────────

# Extract command history and strip line numbers
fzf-history-select() {
  iconv -f utf-8 -t utf-8 -c "$HISTFILE" |  # 移除非法 multibyte
  awk -F'[;:]' '
    /^:/ {
      cmd = substr($0, index($0, $5))
      gsub(/\\/, "\\\\", cmd)  # 避免反斜線破壞 ZLE
      
      ts_cmd = "date -r " $2 " +\"%Y-%m-%d %H:%M:%S\""
      ts_cmd | getline ts
      close(ts_cmd)

      printf "%s | %4d | %s\n", ts, NR, cmd
    }
  ' | fzf --ansi --no-sort --reverse --height=50% \
         --preview 'echo {}' \
         --bind 'ctrl-j:preview-down,ctrl-k:preview-up'
}

fzf-history-widget() {
  local selected cmd
  selected="$(fzf-history-select)"
  cmd="$(echo "$selected" | cut -d'|' -f3- | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  if [[ -n "$cmd" ]]; then
    BUFFER="$cmd"
    CURSOR=${#BUFFER}
  fi
}


# Register ZLE widget and bind to Ctrl+R
zle -N fzf-history-widget
bindkey '^R' fzf-history-widget

