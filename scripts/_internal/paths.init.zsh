# ──────────────────────────────
# Zsh environment paths (init)
# ──────────────────────────────

(( ${+_ZSH_INTERNAL_PATHS_INIT_SOURCED} )) && return 0
typeset -g _ZSH_INTERNAL_PATHS_INIT_SOURCED=1

[[ -d "${ZSH_CACHE_DIR:-${ZDOTDIR:-$HOME/.config/zsh}/cache}" ]] || \
  mkdir -p -- "${ZSH_CACHE_DIR:-${ZDOTDIR:-$HOME/.config/zsh}/cache}"

