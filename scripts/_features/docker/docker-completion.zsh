# Docker completion bootstrap (feature: docker)
#
# Purpose:
# - Generate/cache docker completion scripts into a dedicated fpath dir BEFORE compinit runs.
# - Keep `scripts/interactive/completion.zsh` generic (no docker-specific logic).
#
# What it does:
# - Writes `${ZSH_COMPLETION_CACHE_DIR}/completions/_docker` from `docker completion zsh`.
# - Writes `${ZSH_COMPLETION_CACHE_DIR}/completions/_docker-compose` wrapper (when docker-compose exists).
# - Prepends `${ZSH_COMPLETION_CACHE_DIR}/completions` to `fpath` so compinit can pick them up.
#
# Notes:
# - Runs only in interactive TTY sessions; otherwise it is a no-op.
# - Silent by default; use `ZSH_DEBUG>=2` to see warnings.

(( ${+_ZSH_DOCKER_COMPLETION_BOOTSTRAPPED} )) && return 0
typeset -g _ZSH_DOCKER_COMPLETION_BOOTSTRAPPED=1

if [[ ! -o interactive || ! -t 0 ]]; then
  return 0
fi

if ! (( $+commands[docker] )); then
  return 0
fi

typeset cache_dir="${ZSH_CACHE_DIR-}"
if [[ -z "$cache_dir" ]]; then
  typeset zdotdir="${ZDOTDIR-}"
  [[ -n "$zdotdir" ]] && cache_dir="$zdotdir/cache"
fi
[[ -n "$cache_dir" ]] || cache_dir="$HOME/.config/zsh/cache"

if [[ -z "${ZSH_COMPLETION_CACHE_DIR-}" ]]; then
  typeset -g ZSH_COMPLETION_CACHE_DIR="$cache_dir/completion-cache"
fi

typeset completion_cache_dir="${ZSH_COMPLETION_CACHE_DIR-}"
[[ -d "$completion_cache_dir" ]] || command mkdir -p -- "$completion_cache_dir"

typeset completions_dir="$completion_cache_dir/completions"
[[ -d "$completions_dir" ]] || command mkdir -p -- "$completions_dir"

if (( ${fpath[(Ie)$completions_dir]} == 0 )); then
  fpath=("$completions_dir" $fpath)
fi

typeset docker_bin=''
docker_bin="$(command -v docker 2>/dev/null || true)"
[[ -n "$docker_bin" ]] || return 0

typeset docker_completion="$completions_dir/_docker"
if [[ ! -s "$docker_completion" || "$docker_completion" -ot "$docker_bin" ]]; then
  typeset tmp_file="$docker_completion.$$"
  if command docker completion zsh >| "$tmp_file" 2>/dev/null; then
    command mv -f -- "$tmp_file" "$docker_completion"
  else
    command rm -f -- "$tmp_file" >/dev/null 2>&1 || true
    [[ "${ZSH_DEBUG:-0}" -ge 2 ]] && print -u2 -r -- "docker-completion: failed to generate _docker"
    return 0
  fi
fi

# docker-compose (v1/v2 shim): reuse docker's completion.
if (( $+commands[docker-compose] )); then
  typeset docker_compose_bin=''
  docker_compose_bin="$(command -v docker-compose 2>/dev/null || true)"

  typeset docker_compose_completion="$completions_dir/_docker-compose"
  if [[ ! -s "$docker_compose_completion" || "$docker_compose_completion" -ot "$docker_completion" || ( -n "$docker_compose_bin" && "$docker_compose_completion" -ot "$docker_compose_bin" ) ]]; then
    typeset tmp_file="$docker_compose_completion.$$"
    typeset compose_fn='_docker-compose'
    cat >| "$tmp_file" <<EOF
#compdef docker-compose

${compose_fn}() {
  emulate -L zsh -o extendedglob
  _docker "\$@"
}

compdef ${compose_fn} docker-compose
EOF
    command mv -f -- "$tmp_file" "$docker_compose_completion"
  fi
fi
