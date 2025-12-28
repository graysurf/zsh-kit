source "$ZSH_BOOTSTRAP_SCRIPT_DIR/define-loaders.zsh"

# Ensure source_file function is defined before proceeding
typeset -f source_file &>/dev/null || {
  printf "❌ source_file not defined. Check bootstrap/define-loaders.zsh\n"
  return 1
}


source_file_warn_missing "$ZSH_BOOTSTRAP_SCRIPT_DIR/00-preload.zsh"

# Attempt to load the plugin system, but allow fallback if it fails
if ! source_file_warn_missing "$ZSH_BOOTSTRAP_SCRIPT_DIR/plugins.zsh"; then
  printf "⚠️  Plugin system failed to load, continuing without plugins.\n"
fi

export ZSH_SCRIPT_DIR="$ZDOTDIR/scripts"

export ZSH_PRIVATE_SCRIPT_DIR="$ZDOTDIR/.private"
[[ -d "$ZSH_PRIVATE_SCRIPT_DIR" ]] || mkdir -p "$ZSH_PRIVATE_SCRIPT_DIR"

# ──────────────────────────────
# Script groups (order + exclude)
# ──────────────────────────────
ZSH_SCRIPT_EXCLUDE_LIST=(
  "$ZSH_SCRIPT_DIR"/interactive/**/*.sh(N)
  "$ZSH_SCRIPT_DIR"/interactive/**/*.zsh(N)
)

ZSH_SCRIPT_LAST_LIST=(
  "$ZSH_SCRIPT_DIR/git/git-tools.zsh"
  "$ZSH_SCRIPT_DIR/env.zsh"
)

ZSH_INTERACTIVE_SCRIPT_FIRST_LIST=(
  "$ZSH_SCRIPT_DIR/interactive/runtime.zsh"
  "$ZSH_SCRIPT_DIR/interactive/hotkeys.zsh"
)

ZSH_INTERACTIVE_SCRIPT_LAST_LIST=(
  "$ZSH_SCRIPT_DIR/interactive/plugin-hooks.zsh"
  "$ZSH_SCRIPT_DIR/interactive/completion.zsh"
)

ZSH_PRIVATE_SCRIPT_EXCLUDE_LIST=(
  "$ZSH_PRIVATE_SCRIPT_DIR/development.sh"
)

# ──────────────────────────────
# Load public scripts (excluding special core scripts)
# ──────────────────────────────
load_script_group_ordered "Public Scripts" "$ZSH_SCRIPT_DIR" \
  --exclude "${ZSH_SCRIPT_EXCLUDE_LIST[@]}" \
  --last "${ZSH_SCRIPT_LAST_LIST[@]}"

# ──────────────────────────────
# Load interactive scripts after general scripts
# ──────────────────────────────
load_script_group_ordered "Interactive Scripts" "$ZSH_SCRIPT_DIR/interactive" \
  --first "${ZSH_INTERACTIVE_SCRIPT_FIRST_LIST[@]}" \
  --last "${ZSH_INTERACTIVE_SCRIPT_LAST_LIST[@]}"

# ──────────────────────────────
# Load private scripts
# ──────────────────────────────
load_script_group_ordered "Private Scripts" "$ZSH_PRIVATE_SCRIPT_DIR" \
  --exclude "${ZSH_PRIVATE_SCRIPT_EXCLUDE_LIST[@]}"

# ──────────────────────────────
# Load development.sh last with timing
# ──────────────────────────────
dev_script="$ZSH_PRIVATE_SCRIPT_DIR/development.sh"
if [[ -f "$dev_script" ]]; then
  source_file "$dev_script" "${dev_script:t} (delayed)"
fi
