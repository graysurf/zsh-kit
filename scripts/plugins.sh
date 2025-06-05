# ──────────────────────────────
# Load local zsh plugins manually
# ──────────────────────────────

ZSH_PLUGINS_DIR="$ZDOTDIR/plugins"

# zsh-autosuggestions
if [[ -d "$ZSH_PLUGINS_DIR/zsh-autosuggestions" ]]; then
  source "$ZSH_PLUGINS_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# zsh-completions
if [[ -d "$ZSH_PLUGINS_DIR/zsh-completions" ]]; then
  fpath+=("$ZSH_PLUGINS_DIR/zsh-completions/src")
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

# Set custom data path (must be set before sourcing)
export _Z_DATA="$ZSH_CACHE_DIR/.z"

# Load zsh-z plugin from one of the known locations
if [ -f "$HOME/bin/.zsh-z/zsh-z.plugin.zsh" ]; then
  source "$HOME/bin/.zsh-z/zsh-z.plugin.zsh"
elif [ -f /opt/homebrew/share/zsh-z/zsh-z.plugin.zsh ]; then
  source /opt/homebrew/share/zsh-z/zsh-z.plugin.zsh
elif [ -f /usr/local/share/zsh-z/zsh-z.plugin.zsh ]; then
  source /usr/local/share/zsh-z/zsh-z.plugin.zsh
else
  echo "⚠️  zsh-z plugin not found."
fi

# ──────────────────────────────
# Starship prompt
# ──────────────────────────────

# Use custom Starship config from zsh-kit repo
if [[ -f "$ZDOTDIR/config/starship.toml" ]]; then
  export STARSHIP_CONFIG="$ZDOTDIR/config/starship.toml"
fi

# Initialize Starship (must be after plugin sourcing)
eval "$(starship init zsh)"

# ──────────────────────────────
# Lazy compinit using zsh hooks
# ──────────────────────────────
autoload -Uz compinit

_zsh_lazy_compinit() {
  unfunction _zsh_lazy_compinit
  compinit -C
}

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_COMPDUMP"

if [[ ! -s "$ZSH_COMPDUMP" ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _zsh_lazy_compinit
fi

# ──────────────────────────────
# Shell behavior options
# ──────────────────────────────

# Case-insensitive globbing and matching (for cd, ls, etc.)
setopt nocaseglob
setopt nocasematch

# Enable extended globbing features
setopt extended_glob

# ──────────────────────────────
# History substring search key bindings
# ──────────────────────────────
bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down
