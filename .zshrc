# ──────────────────────────────
# Define Zsh environment paths early (must be first!)
# ──────────────────────────────
export ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$ZDOTDIR/cache}"
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/zcompdump"
export _Z_DATA="$ZSH_CACHE_DIR/.z"
export ZSHZ_DATA="$_Z_DATA"

# History config
export HISTFILE="$ZSH_CACHE_DIR/.zsh_history"
export HISTSIZE=10000
export SAVEHIST=10000

# Enhanced history settings
setopt HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS
setopt HIST_VERIFY HIST_IGNORE_SPACE INC_APPEND_HISTORY SHARE_HISTORY
setopt EXTENDED_HISTORY HIST_FIND_NO_DUPS HIST_SAVE_NO_DUPS

# Show formatted timestamps when using `history`
export HISTTIMEFORMAT='%F %T '

# Ensure cache dir exists
[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p "$ZSH_CACHE_DIR"

export ZSH_BOOTSTRAP_SCRIPT_DIR="$ZDOTDIR/bootstrap"

export ZSH_DEBUG=0
export ZSH_BOOT_WEATHER=true
export ZSH_BOOT_QUOTE=true

# Display current weather if enabled
[[ "$ZSH_BOOT_WEATHER" == true ]] && source "$ZSH_BOOTSTRAP_SCRIPT_DIR/weather.sh"

# Display quote UI if enabled
[[ "$ZSH_BOOT_QUOTE" == true ]] && source "$ZSH_BOOTSTRAP_SCRIPT_DIR/quote-init.sh"

source "$ZSH_BOOTSTRAP_SCRIPT_DIR/bootstrap.sh"
