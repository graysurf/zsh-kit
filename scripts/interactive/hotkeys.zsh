# ────────────────────────────────────────────────────────
# Interactive launcher for `fzf-cli`
# - Bound to Ctrl+F
# - Presents categorized, emoji-enhanced command list via `fzf`
# - Inserts selected subcommand into shell prompt
# ────────────────────────────────────────────────────────

# Only enable fzf-cli widgets when fzf-cli is installed.
if command -v fzf-cli >/dev/null 2>&1; then

# fzf-history-select
# Build and select shell history entries.
# Usage: fzf-history-select [query]
# Output:
# - Returns two lines (key, selected) for consumption by fzf-history.
# Notes:
# - Presents history with timestamps; preview shows formatted time + command.
fzf-history-select() {
  local default_query="${1-}"
  [[ -z "$default_query" ]] && default_query="${BUFFER:-}"

  iconv -f utf-8 -t utf-8 -c "$HISTFILE" |
  awk -F';' '
    /^:/ {
      if (NF < 2) next
      split($1, meta, ":")
      cmd = $2
      ts = meta[2]

      if (cmd ~ /^[[:space:]]*$/) next
      if (cmd ~ /^[[:cntrl:][:punct:][:space:]]*$/) next
      if (cmd ~ /[^[:print:]]/) next

      printf "%s | %4d | %s\n", ts, NR, cmd
    }
  ' | tac | fzf --ansi --reverse --height=50% \
         --query="$default_query" \
         --preview-window='right:50%:wrap' \
         --preview='ts=$(printf "%s\n" {} | cut -d"|" -f1 | sed -E "s/^[[:space:]]+//; s/[[:space:]]+$//"); \
fts=""; \
case "$ts" in (""|*[!0-9]*)) ;; (*) \
  if date -r "$ts" "+%Y-%m-%d %H:%M:%S" >/dev/null 2>&1; then \
    fts=$(date -r "$ts" "+%Y-%m-%d %H:%M:%S"); \
  elif date -d "@$ts" "+%Y-%m-%d %H:%M:%S" >/dev/null 2>&1; then \
    fts=$(date -d "@$ts" "+%Y-%m-%d %H:%M:%S"); \
  fi ;; \
esac; \
cmd=$(printf "%s\n" {} | cut -d"|" -f3- | sed -E "s/^[[:space:]]*(🖥️|🧪|🐧|🐳|🛠️)?[[:space:]]*//"); \
printf "🕒 %s\n\n%s" "$fts" "$cmd"' \
         --expect=enter
}

# fzf-history
# Search and execute a history command.
# Usage: fzf-history [query]
# Notes:
# - Uses fzf-history-select; executes selected command.
fzf-history() {
  local selected='' output='' cmd=''

  output="$(fzf-history-select "$*")"
  selected="$(printf "%s\n" "$output" | sed -n '2p')"

  cmd="$(printf "%s\n" "$selected" | cut -d'|' -f3- | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  cmd="$(printf "%s\n" "$cmd" | sed -E 's/^[[:space:]]*(🖥️|🧪|🐧|🐳|🛠️)?[[:space:]]*//')"

  [[ -n "$cmd" ]] && eval "$cmd"
}

# fzf-cli-launcher-widget
# ZLE widget: pick an `fzf-cli` subcommand via `fzf` and execute it.
# Usage: fzf-cli-launcher-widget
# Notes:
# - Bound to Ctrl+F.
# - Requires an interactive ZLE session and `fzf`.
fzf-cli-launcher-widget() {
  typeset raw='' selected='' subcommand=''

  raw=$(cat <<EOF | fzf --ansi \
    --prompt="🔧 fzf-cli > " \
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

  BUFFER="fzf-cli $subcommand"
  CURSOR=${#BUFFER}
  zle accept-line
  return 0
}

# Register ZLE widget and bind to Ctrl+F
zle -N fzf-cli-launcher-widget
bindkey '^F' fzf-cli-launcher-widget

# ────────────────────────────────────────────────────────
# `fzf-cli file` widget (intentionally unbound)
# ────────────────────────────────────────────────────────

# fzf-cli-file-widget
# ZLE widget: prefix the current buffer with `fzf-cli file` and execute it.
# Usage: fzf-cli-file-widget
# Notes:
# - Intentionally not bound to a hotkey.
fzf-cli-file-widget() {
  BUFFER="fzf-cli file $BUFFER"
  CURSOR=${#BUFFER}
  zle accept-line
  return 0
}

zle -N fzf-cli-file-widget

# ────────────────────────────────────────────────────────
# Bind `fzf-cli def` to Ctrl+T
# ────────────────────────────────────────────────────────

# fzf-cli-def-widget
# ZLE widget: prefix the current buffer with `fzf-cli def` and execute it.
# Usage: fzf-cli-def-widget
# Notes:
# - Bound to Ctrl+T.
fzf-cli-def-widget() {
  BUFFER="fzf-cli def $BUFFER"
  CURSOR=${#BUFFER}
  zle accept-line
  return 0
}

zle -N fzf-cli-def-widget
bindkey '^T' fzf-cli-def-widget

# ────────────────────────────────────────────────────────
# Bind `fzf-cli git-commit` to Ctrl+G
# ────────────────────────────────────────────────────────

# fzf-cli-git-commit-widget
# ZLE widget: prefix the current buffer with `fzf-cli git-commit` and execute it.
# Usage: fzf-cli-git-commit-widget
# Notes:
# - Bound to Ctrl+G.
fzf-cli-git-commit-widget() {
  BUFFER="fzf-cli git-commit $BUFFER"
  CURSOR=${#BUFFER}
  zle accept-line
  return 0
}

zle -N fzf-cli-git-commit-widget
bindkey '^G' fzf-cli-git-commit-widget

fi

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
# - Depends on `fzf-history-select` (provided by the core fzf helpers).
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
# Codex CLI hotkeys (optional)
# ────────────────────────────────────────────────────────

# Bind `codex-cli diag rate-limits --all --async` to Ctrl+U when codex-cli is installed.
if command -v codex-cli >/dev/null 2>&1; then
  # codex-cli-rate-limits-async-widget
  # ZLE widget: run `codex-cli diag rate-limits --all --async` without clobbering the current buffer.
  codex-cli-rate-limits-async-widget() {
    emulate -L zsh
    setopt localoptions pipe_fail

    local saved_buffer="${BUFFER}"
    local -i saved_cursor="${CURSOR}"
    local -i rc=0

    zle -I
    codex-cli diag rate-limits --all --async
    rc=$?

    BUFFER="${saved_buffer}"
    CURSOR="${saved_cursor}"
    return $rc
  }

  zle -N codex-cli-rate-limits-async-widget
  bindkey '^U' codex-cli-rate-limits-async-widget
fi
