# ──────────────────────────────
# Define Zsh environment paths early (must be first!)
# ──────────────────────────────
export ZDOTDIR="$HOME/.config/zsh"
export ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$ZDOTDIR/cache}"
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/zcompdump"
export _Z_DATA="$ZSH_CACHE_DIR/.z"
export ZSHZ_DATA="$_Z_DATA"
export HISTFILE="$ZSH_CACHE_DIR/.zsh_history"

# Ensure cache dir exists
[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p "$ZSH_CACHE_DIR"

export ZSH_SCRIPT_DIR="$ZDOTDIR/scripts"
export ZSH_PRIVATE_SCRIPT_DIR="$ZDOTDIR/.private"

source "$ZSH_SCRIPT_DIR/bootstrap.sh"

# ──────────────────────────────
# Exclude list (array version)
# ──────────────────────────────
ZSH_SCRIPT_EXCLUDE_LIST=(
  "$ZSH_SCRIPT_DIR/bootstrap.sh"
  "$ZSH_SCRIPT_DIR/env.sh"
  "$ZSH_SCRIPT_DIR/plugins.sh"
  "$ZSH_SCRIPT_DIR/completion.zsh"
  "$ZSH_PRIVATE_SCRIPT_DIR/development.sh"
)

ZSH_PRIVATE_SCRIPT_EXCLUDE_LIST=(
  "$ZSH_PRIVATE_SCRIPT_DIR/development.sh"
)

# ──────────────────────────────
# Load public scripts (excluding special core scripts)
# ──────────────────────────────
load_script_group "Public Scripts" "$ZSH_SCRIPT_DIR" "${ZSH_SCRIPT_EXCLUDE_LIST[@]}"

# ──────────────────────────────
# Source environment and plugins
# ──────────────────────────────
load_with_timing "$ZDOTDIR/scripts/env.sh"
load_with_timing "$ZDOTDIR/scripts/plugins.sh"
load_with_timing "$ZDOTDIR/scripts/completion.zsh"

# ──────────────────────────────
# Load private scripts
# ──────────────────────────────
load_script_group "Private Scripts" "$ZSH_PRIVATE_SCRIPT_DIR" "${ZSH_PRIVATE_SCRIPT_EXCLUDE_LIST[@]}"

# ──────────────────────────────
# Load development.sh last with timing
# ──────────────────────────────
dev_script="$ZSH_PRIVATE_SCRIPT_DIR/development.sh"
[[ -f "$dev_script" ]] && load_with_timing "$dev_script" "$(basename "$dev_script") (delayed)"
