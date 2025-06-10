# ──────────────────────────────
# Zoxide smart directory jumping
# ──────────────────────────────

# Initialize zoxide (faster alternative to z/zsh-z)
eval "$(zoxide init zsh)"

# Wrapper to execute `eza -alh` after directory jump
__zoxide_cd() {
  builtin cd -- "$1" || return
  echo -e "\n📁 Now in: $PWD\n"
  eza -alh --icons --group-directories-first --time-style=iso
}

alias z=__zoxide_z

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