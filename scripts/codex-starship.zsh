# codex-starship: Starship prompt helper for Codex rate limits.
#
# This module is intended to be sourced by cached CLI wrappers (see `scripts/_internal/wrappers.zsh`)
# and should remain quiet at source-time.

_codex_starship_usage() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset fd="${1-1}"
  print -u"$fd" -r -- 'Usage: codex-starship [--no-5h] [--ttl <duration>]'
  print -u"$fd" -r --
  print -u"$fd" -r -- 'Options:'
  print -u"$fd" -r -- '  --no-5h            Hide the 5h window output'
  print -u"$fd" -r -- '  --ttl <duration>   Cache TTL (e.g. 1m, 5m); default: 5m'
  print -u"$fd" -r -- '  -h, --help         Show help'
  return 0
}

codex-starship() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  zmodload zsh/zutil 2>/dev/null || return 0

  typeset show_5h='true'
  typeset ttl='5m'

  typeset -A opts=()
  zparseopts -D -E -A opts -- \
    h -help \
    -no-5h \
    -ttl: || {
    _codex_starship_usage 2
    return 2
  }

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    _codex_starship_usage 1
    return 0
  fi

  if (( ${+opts[--no-5h]} )); then
    show_5h='false'
  fi

  if [[ -n "${opts[--ttl]-}" ]]; then
    ttl="${opts[--ttl]}"
  fi

  # MVP scaffold: the Starship module should be hidden until the upstream data sources and cache
  # are wired. Do not print anything (and exit 0) to satisfy "fail closed" prompt behavior.
  : "$show_5h" "$ttl"
  return 0
}
