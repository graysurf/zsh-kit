# ──────────────────────────────
# Zoxide smart directory jumping
# ──────────────────────────────

# Initialize zoxide (faster alternative to z/zsh-z)
eval "$(zoxide init zsh)"

# Override `z` to: jump to matched dir AND run `ll`
z() {
  if zoxide query -l "$@" &>/dev/null; then
    builtin cd "$(zoxide query "$@")" && {
      echo -e "\n📁 Now in: $PWD\n"
      eza -alh --icons --group-directories-first --time-style=iso
    }
  else
    echo "❌ No matching directory for: $*"
    return 1
  fi
}

# ──────────────────────────────
# Starship prompt
# ──────────────────────────────

if [[ -f "$ZDOTDIR/config/starship.toml" ]]; then
  export STARSHIP_CONFIG="$ZDOTDIR/config/starship.toml"
fi
eval "$(starship init zsh)"

# ──────────────────────────────
# Shell behavior options
# ──────────────────────────────

setopt nocaseglob
setopt nocasematch
setopt extended_glob

# ──────────────────────────────
# History substring search key bindings
# ──────────────────────────────

bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down