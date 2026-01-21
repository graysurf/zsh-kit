# ──────────────────────────────
# Define Zsh environment paths early (must be first!)
# ──────────────────────────────

# `.zshrc` is loaded for interactive shells. If you need something to exist in *all* shells
# (including `zsh -c '...'` and subshells), put it in `$ZDOTDIR/.zshenv` or
# `scripts/_internal/paths.exports.zsh` instead.
#
# See `docs/guides/startup-files.md` for the full startup file roles and load order.

typeset paths_exports="${ZDOTDIR:-$HOME/.config/zsh}/scripts/_internal/paths.exports.zsh"
typeset paths_init="${ZDOTDIR:-$HOME/.config/zsh}/scripts/_internal/paths.init.zsh"

# Normally loaded via `$ZDOTDIR/.zshenv`. Keep a fallback for manual sourcing
# (including sessions started with `zsh -f`).
if [[ -z "${ZSH_BOOTSTRAP_SCRIPT_DIR-}" || -z "${ZSH_CACHE_DIR-}" ]]; then
  [[ -r "$paths_exports" ]] && source "$paths_exports"
fi
[[ -r "$paths_init" ]] && source "$paths_init"

# ──────────────────────────────
# Cached CLI wrappers (for subshells like fzf preview)
# ──────────────────────────────
typeset wrappers_zsh="$ZSH_SCRIPT_DIR/_internal/wrappers.zsh"
typeset wrappers_bin="$ZSH_CACHE_DIR/wrappers/bin"

if [[ -f "$wrappers_zsh" ]]; then
  source "$wrappers_zsh"
  [[ -o interactive ]] && _wrappers::ensure_all || _wrappers::ensure_all >/dev/null 2>&1 || true
fi

if [[ -d "$wrappers_bin" ]] && (( ${path[(Ie)$wrappers_bin]} == 0 )); then
  path=("$wrappers_bin" $path)
fi

# ──────────────────────────────
# History
# ──────────────────────────────
# macOS ships `/etc/zshrc`, which sets `HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history`.
# Re-assert our desired history file under `$ZSH_CACHE_DIR` after global rc files run.
export HISTFILE="$ZSH_CACHE_DIR/.zsh_history"

export HISTSIZE=10000
export SAVEHIST=10000

setopt HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS
setopt HIST_VERIFY HIST_IGNORE_SPACE INC_APPEND_HISTORY SHARE_HISTORY
setopt EXTENDED_HISTORY HIST_FIND_NO_DUPS HIST_SAVE_NO_DUPS

export HISTTIMEFORMAT='%F %T '

# ──────────────────────────────
# Bootstrap flags
# ──────────────────────────────
export ZSH_DEBUG="${ZSH_DEBUG:-0}"
export ZSH_BOOT_WEATHER_ENABLED="${ZSH_BOOT_WEATHER_ENABLED-true}"
export ZSH_BOOT_QUOTE_ENABLED="${ZSH_BOOT_QUOTE_ENABLED-true}"
export ZSH_BOOT_FEATURES_ENABLED="${ZSH_BOOT_FEATURES_ENABLED-false}"

# ──────────────────────────────
# Startup banner (optional)
# ──────────────────────────────
# Note: This runs in interactive shells (login or not). The sourced scripts include their own
# "run once" guards to avoid repeating the banner in nested shells.
typeset preload_zsh="$ZSH_BOOTSTRAP_SCRIPT_DIR/00-preload.zsh"
[[ -r "$preload_zsh" ]] && source "$preload_zsh"

zsh_env::is_true "${ZSH_BOOT_WEATHER_ENABLED-}" "ZSH_BOOT_WEATHER_ENABLED" && source "$ZSH_BOOTSTRAP_SCRIPT_DIR/weather.zsh"
zsh_env::is_true "${ZSH_BOOT_QUOTE_ENABLED-}" "ZSH_BOOT_QUOTE_ENABLED" && source "$ZSH_BOOTSTRAP_SCRIPT_DIR/quote-init.zsh"

# ──────────────────────────────
# Bootstrap
# ──────────────────────────────
source "$ZSH_BOOTSTRAP_SCRIPT_DIR/bootstrap.zsh"

# ──────────────────────────────
# Enabled features (always visible)
# ──────────────────────────────
# Print the effective, successfully-loaded feature list (from `ZSH_FEATURES`).
if [[ -t 1 ]] && zsh_env::is_true "${ZSH_BOOT_FEATURES_ENABLED-}" "ZSH_BOOT_FEATURES_ENABLED"; then
  typeset -a _loaded_features=() _missing_features=() _failed_features=()
  (( ${+ZSH_FEATURES_LOADED} )) && _loaded_features=("${ZSH_FEATURES_LOADED[@]}")
  (( ${+ZSH_FEATURES_MISSING} )) && _missing_features=("${ZSH_FEATURES_MISSING[@]}")
  (( ${+ZSH_FEATURES_FAILED} )) && _failed_features=("${ZSH_FEATURES_FAILED[@]}")

  typeset features_summary="(none)"
  if (( ${#_loaded_features[@]} > 0 )); then
    features_summary="${(j:,:)_loaded_features}"
  fi

  typeset msg="🧩 Features: $features_summary"
  (( ${#_missing_features[@]} > 0 )) && msg+=" (missing: ${(j:,:)_missing_features})"
  (( ${#_failed_features[@]} > 0 )) && msg+=" (failed: ${(j:,:)_failed_features})"

  print -r -- "$msg"
fi
