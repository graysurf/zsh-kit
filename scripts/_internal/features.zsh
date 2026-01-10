# ──────────────────────────────
# Optional feature flags (ZSH_FEATURES)
# ──────────────────────────────
#
# This module parses the comma-separated `ZSH_FEATURES` env var and exposes:
#
# - zsh_features::enabled <name>
# - zsh_features::list
#
# Notes:
# - Feature names are lowercased.
# - Only `[a-z0-9_-]` are accepted (others are ignored).
# - This file is under `_internal/` so it is not auto-loaded; callers opt in via `source`.

(( ${+_ZSH_INTERNAL_FEATURES_SOURCED} )) && return 0
typeset -g _ZSH_INTERNAL_FEATURES_SOURCED=1

typeset -g _ZSH_FEATURES_CACHE_RAW=''
typeset -ga _ZSH_FEATURES_CACHE_LIST=()
typeset -gA _ZSH_FEATURES_CACHE_SET=()

# _zsh_features::refresh_cache
# Refresh the parsed features cache if `ZSH_FEATURES` has changed.
# Usage: _zsh_features::refresh_cache
_zsh_features::refresh_cache() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset raw="${ZSH_FEATURES-}"
  raw="${raw:l}"

  if [[ "$raw" == "${_ZSH_FEATURES_CACHE_RAW-}" ]]; then
    return 0
  fi

  _ZSH_FEATURES_CACHE_RAW="$raw"
  _ZSH_FEATURES_CACHE_LIST=()
  _ZSH_FEATURES_CACHE_SET=()

  [[ -n "$raw" ]] || return 0

  typeset -a parts=(${(s:,:)raw})
  typeset part='' token='' cleaned=''
  for part in "${parts[@]}"; do
    token="$part"
    token="${token//[[:space:]]/}"
    [[ -n "$token" ]] || continue

    cleaned="${token//[^a-z0-9_-]/}"
    [[ -n "$cleaned" && "$cleaned" == "$token" ]] || continue

    if [[ -z ${_ZSH_FEATURES_CACHE_SET[$token]-} ]]; then
      _ZSH_FEATURES_CACHE_SET[$token]=1
      _ZSH_FEATURES_CACHE_LIST+=("$token")
    fi
  done

  return 0
}

# zsh_features::enabled <name>
# Return 0 if the given feature name is enabled in `ZSH_FEATURES`.
# Usage: zsh_features::enabled <name>
zsh_features::enabled() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset name="${1-}"
  [[ -n "$name" ]] || return 1
  name="${name:l}"

  _zsh_features::refresh_cache
  [[ -n ${_ZSH_FEATURES_CACHE_SET[$name]-} ]]
}

# zsh_features::list
# Print enabled feature names (one per line), in the order they appear in `ZSH_FEATURES`.
# Usage: zsh_features::list
zsh_features::list() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _zsh_features::refresh_cache
  print -rl -- "${_ZSH_FEATURES_CACHE_LIST[@]}"
}

