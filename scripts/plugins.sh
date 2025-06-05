# ──────────────────────────────
# Load local zsh plugins manually
# ──────────────────────────────

ZSH_PLUGINS_DIR="$ZDOTDIR/plugins"

# zsh-autosuggestions
if [[ -d "$ZSH_PLUGINS_DIR/zsh-autosuggestions" ]]; then
  source "$ZSH_PLUGINS_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# zsh-syntax-highlighting
if [[ -d "$ZSH_PLUGINS_DIR/zsh-syntax-highlighting" ]]; then
  source "$ZSH_PLUGINS_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# zsh-history-substring-search
if [[ -d "$ZSH_PLUGINS_DIR/zsh-history-substring-search" ]]; then
  source "$ZSH_PLUGINS_DIR/zsh-history-substring-search/zsh-history-substring-search.zsh"
fi

# ──────────────────────────────
# Zoxide smart directory jumping
# ──────────────────────────────

# Initialize zoxide (faster alternative to z/zsh-z)
eval "$(zoxide init zsh)"

# Override `z` to: jump to matched dir AND run `ll`
z() {
  if zoxide query -l "$@" &>/dev/null; then
    # If there's a match, jump and list contents
    builtin cd "$(zoxide query "$@")" && ll
  else
    # No match found
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
# Completion system (eager load)
# ──────────────────────────────
autoload -Uz compinit
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_COMPDUMP"
compinit -C

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
