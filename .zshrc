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
# nils-cli dev override (before Starship init)
# ──────────────────────────────
# Apply the interactive override before bootstrap so Starship's session
# environment and ordinary shell commands agree. Homebrew login setup now
# preserves the PATH order already established by earlier startup layers.
# The local dev install (`scripts/install-local-release-binaries.sh` →
# ~/.local/nils-cli/bin) wins over the brew formula when populated. After
# `brew upgrade nils-cli` the bump skill clears that dir, so brew wins again.
# `typeset -U path` (set in paths.exports.zsh) dedups the earlier instance.
if [[ -d "$HOME/.local/nils-cli/bin" ]]; then
  path=("$HOME/.local/nils-cli/bin" $path)
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
# External tool launchers
# ──────────────────────────────
# agent-memory: defines `claude-persona` + per-persona `claude-<id>` shortcuts.
[[ -r "$HOME/.config/agent-memory/shell/agent-memory.zsh" ]] && \
  source "$HOME/.config/agent-memory/shell/agent-memory.zsh"

# codex-workspace-launcher: defines `cws` (create/ls/exec/tunnel/rm/reset).
[[ -r "$HOME/.config/codex-workspace-launcher/cws.zsh" ]] && \
  source "$HOME/.config/codex-workspace-launcher/cws.zsh"

# nils-cli aliases (gates on interactive + resolves Homebrew prefix).
[[ -r "$ZSH_SCRIPT_DIR/nils-cli-aliases.zsh" ]] && \
  source "$ZSH_SCRIPT_DIR/nils-cli-aliases.zsh"

# tg-channel: scratch Claude Code session bridging Telegram channel plugin.
# Interactive-only — runs the official telegram channel plugin in a temp
# session id and cleans up `.claude/projects/-Users-terry/<sid>{,.jsonl}` on exit.
alias tg-channel='(
  set -e
  sid=$(uuidgen | tr "A-Z" "a-z")
  proj="$HOME/.claude/projects/-Users-terry"
  trap "rm -rf \"$proj/$sid.jsonl\" \"$proj/$sid\"" EXIT
  cd "$HOME"
  DISABLE_ERROR_REPORTING=1 \
  claude --session-id "$sid" --channels plugin:telegram@claude-plugins-official
)'

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

# bun completions
typeset bun_completion_file="$HOME/.bun/_bun"
[[ ! -s "$bun_completion_file" ]] || source "$bun_completion_file"
unset bun_completion_file
