# ──────────────────────────────
# Define Zsh environment paths early (must be first!)
# ──────────────────────────────

# `.zshrc` is loaded for interactive shells. If you need something to exist in *all* shells
# (including `zsh -c '...'` and subshells), put it in `$ZDOTDIR/.zshenv` or
# `scripts/_internal/paths.exports.zsh` instead.
#
# See `docs/startup-files.md` for the full startup file roles and load order.

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
typeset wrappers_check_cmd='codex-starship'
typeset wrappers_check_path="$wrappers_bin/$wrappers_check_cmd"
if [[ -f "$wrappers_zsh" && ! -x "$wrappers_check_path" ]]; then
  source "$wrappers_zsh"
  [[ -o interactive ]] && _wrappers::ensure_all || _wrappers::ensure_all >/dev/null 2>&1 || true
fi
if [[ -x "$wrappers_check_path" ]]; then
  path=("$wrappers_bin" $path)
fi

# ──────────────────────────────
# History
# ──────────────────────────────
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
export ZSH_BOOT_WEATHER="${ZSH_BOOT_WEATHER:-true}"
export ZSH_BOOT_QUOTE="${ZSH_BOOT_QUOTE:-true}"

# ──────────────────────────────
# Startup banner (optional)
# ──────────────────────────────
# Note: This runs in interactive shells (login or not). The sourced scripts include their own
# "run once" guards to avoid repeating the banner in nested shells.
[[ "$ZSH_BOOT_WEATHER" == true ]] && source "$ZSH_BOOTSTRAP_SCRIPT_DIR/weather.zsh"
[[ "$ZSH_BOOT_QUOTE" == true ]] && source "$ZSH_BOOTSTRAP_SCRIPT_DIR/quote-init.zsh"

# ──────────────────────────────
# Bootstrap
# ──────────────────────────────
source "$ZSH_BOOTSTRAP_SCRIPT_DIR/bootstrap.zsh"
