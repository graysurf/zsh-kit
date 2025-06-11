source "$ZSH_BOOTSTRAP_SCRIPT_DIR/define-loaders.sh"

# Ensure load_script function is defined before proceeding
typeset -f load_script &>/dev/null || {
  echo "❌ load_script not defined. Check bootstrap/define-loaders.sh"
  return 1
}

load_script "$ZSH_BOOTSTRAP_SCRIPT_DIR/00-preload.sh"

# Attempt to load the plugin system, but allow fallback if it fails
if ! load_script "$ZSH_BOOTSTRAP_SCRIPT_DIR/plugins.sh"; then
  echo "⚠️  Plugin system failed to load, continuing without plugins."
fi

export ZSH_SCRIPT_DIR="$ZDOTDIR/scripts"

export ZSH_PRIVATE_SCRIPT_DIR="$ZDOTDIR/.private"
[[ -d "$ZSH_PRIVATE_SCRIPT_DIR" ]] || mkdir -p "$ZSH_PRIVATE_SCRIPT_DIR"

# ──────────────────────────────
# Exclude list (array version)
# ──────────────────────────────
ZSH_SCRIPT_EXCLUDE_LIST=(
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
