safe_unalias vicd fdf fdd cat batp bat-all bff zdefs \
             fsearch reload execz histflush edit-zsh y cheat

# ────────────────────────────────────────────────────────
# Basic editors & overrides
# ────────────────────────────────────────────────────────

alias vi='nvim'

# Override 'cd' to auto-list
cd() {
  builtin cd "$@" && eza -alh --icons --group-directories-first --time-style=iso
}

# ────────────────────────────────────────────────────────
# fd aliases (file and directory search)
# ────────────────────────────────────────────────────────

alias fdf='fd --type f --hidden --follow --exclude .git'
alias fdd='fd --type d --hidden --follow --exclude .git'

# ────────────────────────────────────────────────────────
# bat aliases (syntax-highlighted file viewing)
# ────────────────────────────────────────────────────────

# Replace cat with bat for plain, no-pager display
alias cat='bat --style=plain --pager=never'

# Pretty bat view: line numbers, paging, theme
alias batp='bat --style=numbers --paging=always --theme="TwoDark"'

# ────────────────────────────────────────────────────────
# fd + bat + fzf integration functions
# ────────────────────────────────────────────────────────

# bff: select and preview multiple files using bat
bat-all() {
  fdf | fzf -m --preview 'bat --color=always --style=numbers {}' |
    xargs -r bat --style=numbers --paging=always
}
alias bff='bat-all'

# Show current shell aliases, functions, and environment variables for debugging
zdefs() {
  {
    echo "🔗 Aliases:"
    alias | sed 's/^/  /'

    echo "\n🔧 Functions:"
    for fn in ${(k)functions}; do
      echo "  $fn"
    done

    echo "\n🌱 Environment Variables:"
    printenv | sort | sed 's/^/  /'
  } | fzf --ansi --header="🔍 Zsh Definitions (aliases, functions, env)" --preview-window=wrap
}

# fsearch: search for file content and preview with bat + ripgrep
fsearch() {
  typeset query="$1"
  fd --type f --hidden --exclude .git |
    fzf --preview "bat --color=always --style=numbers {} | rg --color=always --context 5 '$query'" \
        --bind=ctrl-j:preview-down \
        --bind=ctrl-k:preview-up 
}

# ────────────────────────────────────────────────────────
# Reload the Zsh environment via bootstrap init
# Use for small config changes without restarting shell
# ────────────────────────────────────────────────────────
reload() {
  if source "$ZDOTDIR/bootstrap/bootstrap.sh"; then
    echo -e "\n🔁 Reloaded bootstrap/bootstrap.sh"
    echo -e "💡 For major changes, consider running: execz"
  else
    echo -e "\n❌ Failed to reload Zsh environment"
  fi
}

# ────────────────────────────────────────────────────────
# Restart shell completely with a fresh session
# Useful after modifying core loader, plugin system, etc.
# ────────────────────────────────────────────────────────
execz() {
  echo -e "\n🚪 Restarting Zsh shell (exec zsh)..."
  echo -e "🧼 This will start a clean session using current configs.\n"
  exec zsh
}

# ────────────────────────────────────────────────────────
# Force flush memory history to file
# reload latest history entries
# ────────────────────────────────────────────────────────
histflush() {
  fc -AI  # Append memory history, re-read file
}


# ────────────────────────────────────────────────────────
# Open your Zsh config directory in VSCode
# ────────────────────────────────────────────────────────
edit-zsh() {
  typeset cwd="$(pwd)"
  code "$ZDOTDIR"
  cd "$cwd" >/dev/null
}

# ────────────────────────────────────────────────────────
# Fuzzy cd using Yazi, then jump to selected directory
# ────────────────────────────────────────────────────────
y() {
  typeset tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(< "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# ────────────────────────────────────────────────────────
# Query cheat.sh (curl-based CLI cheatsheets)
# ────────────────────────────────────────────────────────
cheat() {
  curl -s cheat.sh/"$@"
}
