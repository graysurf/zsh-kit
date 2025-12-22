# ──────────────────────────────
# Zoxide smart directory jumping
# ──────────────────────────────

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  alias z=__zoxide_z
fi

# Wrapper to execute `eza -alh` after directory jump
__zoxide_cd() {
  builtin cd -- "$1" || return
  printf "\n📁 Now in: %s\n\n" "$PWD"
  eza -alh --icons --group-directories-first --time-style=iso
}


# ──────────────────────────────
# Starship prompt
# ──────────────────────────────

if [[ -f "$ZDOTDIR/config/starship.toml" ]]; then
  export STARSHIP_CONFIG="$ZDOTDIR/config/starship.toml"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# ──────────────────────────────
# Shell behavior options
# ──────────────────────────────

setopt nocaseglob
setopt nocasematch
setopt extended_glob

# ──────────────────────────────
# History substring search key bindings
# ──────────────────────────────

if (( ${+widgets[history-substring-search-up]} && ${+widgets[history-substring-search-down]} )); then
  if [[ -n "${terminfo[kcuu1]-}" ]]; then
    bindkey "${terminfo[kcuu1]}" history-substring-search-up
  fi
  if [[ -n "${terminfo[kcud1]-}" ]]; then
    bindkey "${terminfo[kcud1]}" history-substring-search-down
  fi
  bindkey -M vicmd 'k' history-substring-search-up
  bindkey -M vicmd 'j' history-substring-search-down
fi
