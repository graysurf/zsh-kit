# ────────────────────────────────────────────────────────
# Basic editors & overrides
# ────────────────────────────────────────────────────────

alias vi='nvim'

# Show current shell aliases, functions, and environment variables for debugging
zdef() {
  echo "🔗 Aliases:"
  alias

  echo "\n🔧 Functions:"
  for fn in ${(k)functions}; do
    echo "$fn"
  done

  echo "\n🌱 Environment Variables:"
  printenv | sort
}

# Override 'cd' to auto-list
cd() {
  builtin cd "$@" && eza -alh --icons --group-directories-first --time-style=iso
}

# ────────────────────────────────────────────────────────
# Unalias to avoid redefinition
# ────────────────────────────────────────────────────────

unalias fdf fdd batp bff cat z 2>/dev/null

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

# fsearch: search for file content and preview with bat + ripgrep
fsearch() {
  typeset query="$1"
  fd --type f --hidden --exclude .git |
    fzf --preview "bat --color=always --style=numbers {} | rg --color=always --context 5 '$query'" \
        --bind=ctrl-j:preview-down \
        --bind=ctrl-k:preview-up 
}
