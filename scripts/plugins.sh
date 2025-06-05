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
# zsh-z (jump around like z, but native zsh)
# ──────────────────────────────

export _Z_DATA="$ZSH_CACHE_DIR/.z"

if [ -f "$HOME/bin/.zsh-z/zsh-z.plugin.zsh" ]; then
  source "$HOME/bin/.zsh-z/zsh-z.plugin.zsh"
elif [ -f /opt/homebrew/share/zsh-z/zsh-z.plugin.zsh ]; then
  source /opt/homebrew/share/zsh-z/zsh-z.plugin.zsh
elif [ -f /usr/local/share/zsh-z/zsh-z.plugin.zsh ]; then
  source "/usr/local/share/zsh-z/zsh-z.plugin.zsh"
else
  echo "⚠️  zsh-z plugin not found."
fi

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
