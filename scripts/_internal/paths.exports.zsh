# ──────────────────────────────
# Define Zsh environment paths (exports only)
# ──────────────────────────────
(( ${+_ZSH_INTERNAL_PATHS_EXPORTS_SOURCED} )) && return 0
typeset -g _ZSH_INTERNAL_PATHS_EXPORTS_SOURCED=1

export ZSH_CONFIG_DIR="${ZSH_CONFIG_DIR:-$ZDOTDIR/config}"
export ZSH_BOOTSTRAP_SCRIPT_DIR="${ZSH_BOOTSTRAP_SCRIPT_DIR:-$ZDOTDIR/bootstrap}"
export ZSH_SCRIPT_DIR="${ZSH_SCRIPT_DIR:-$ZDOTDIR/scripts}"
export ZSH_TOOLS_DIR="${ZSH_TOOLS_DIR:-$ZDOTDIR/tools}"
export ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$ZDOTDIR/cache}"
export ZSH_COMPDUMP="${ZSH_COMPDUMP:-$ZSH_CACHE_DIR/.zcompdump}"
export HISTFILE="$ZSH_CACHE_DIR/.zsh_history"

# ──────────────────────────────
# PATH
# ──────────────────────────────
# Use unique path entries (prevents duplicates)
typeset -U path PATH

# Prepend critical paths to PATH
path=(
  /usr/local/bin
  /usr/bin
  $HOME/bin
  $HOME/.local/bin
  $path
)
