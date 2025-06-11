# ──────────────────────────────
# Define Zsh environment paths early (must be first!)
# ──────────────────────────────
export ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$ZDOTDIR/cache}"
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/zcompdump"
export _Z_DATA="$ZSH_CACHE_DIR/.z"
export ZSHZ_DATA="$_Z_DATA"

export HISTFILE="$ZSH_CACHE_DIR/.zsh_history"
export HISTSIZE=10000
export SAVEHIST=20000

setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_SPACE

# Ensure cache dir exists
[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p "$ZSH_CACHE_DIR"

export ZSH_BOOTSTRAP_SCRIPT_DIR="$ZDOTDIR/bootstrap"

source "$ZSH_BOOTSTRAP_SCRIPT_DIR/bootstrap.sh"
