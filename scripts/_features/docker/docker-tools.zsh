# ────────────────────────────────────────────────────────
# docker-tools (feature: docker)
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias docker-tools
fi

typeset -ga _ZSH_DOCKER_COMPOSE_CMD_CACHE=()
typeset -gi _ZSH_DOCKER_COMPOSE_CMD_CACHE_READY=0

# _docker_compose_resolve_cmd
# Resolve the docker compose command into a word array (cached).
# Usage: _docker_compose_resolve_cmd
# Env:
# - ZSH_DOCKER_COMPOSE_CMD: override compose command (e.g. 'docker compose' or 'docker-compose')
_docker_compose_resolve_cmd() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset override="${ZSH_DOCKER_COMPOSE_CMD-}"
  if [[ -n "$override" ]]; then
    _ZSH_DOCKER_COMPOSE_CMD_CACHE=(${(z)override})
    _ZSH_DOCKER_COMPOSE_CMD_CACHE_READY=1
    return 0
  fi

  if (( _ZSH_DOCKER_COMPOSE_CMD_CACHE_READY )); then
    return 0
  fi

  if (( $+commands[docker] )) && command docker compose version >/dev/null 2>&1; then
    _ZSH_DOCKER_COMPOSE_CMD_CACHE=(docker compose)
  elif (( $+commands[docker-compose] )); then
    _ZSH_DOCKER_COMPOSE_CMD_CACHE=(docker-compose)
  elif (( $+commands[docker] )); then
    _ZSH_DOCKER_COMPOSE_CMD_CACHE=(docker compose)
  else
    _ZSH_DOCKER_COMPOSE_CMD_CACHE=()
    print -u2 -r -- "docker-tools: docker is not installed"
    return 127
  fi

  _ZSH_DOCKER_COMPOSE_CMD_CACHE_READY=1
  return 0
}

# _docker_compose [args...]
# Execute docker compose (v2) with a fallback to docker-compose if needed.
# Usage: _docker_compose [args...]
_docker_compose() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  _docker_compose_resolve_cmd || return $?
  if (( ${#_ZSH_DOCKER_COMPOSE_CMD_CACHE[@]} == 0 )); then
    return 127
  fi

  command -- "${_ZSH_DOCKER_COMPOSE_CMD_CACHE[@]}" "$@"
}

# docker-container-sh [-u|--user <user>|--root] <container>
# Exec into a running container with the best available shell (zsh -> bash -> sh).
# Usage: docker-container-sh [-u|--user <user>|--root] <container>
docker-container-sh() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -A opts=()
  if ! zmodload zsh/zutil 2>/dev/null; then
    print -u2 -r -- "docker-container-sh: zsh/zutil module is required for option parsing"
    return 1
  fi
  zparseopts -D -E -A opts -- h -help u: -user: r -root

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print -r -- "Usage: docker-container-sh [-u|--user <user>|--root] <container>"
    return 0
  fi

  typeset container="${1-}"
  if [[ -z "$container" ]]; then
    print -u2 -r -- "Usage: docker-container-sh [-u|--user <user>|--root] <container>"
    return 2
  fi

  typeset user=''
  if (( ${+opts[-r]} || ${+opts[--root]} )); then
    user='root'
  elif (( ${+opts[-u]} )); then
    user="${opts[-u]}"
  elif (( ${+opts[--user]} )); then
    user="${opts[--user]}"
  fi

  typeset -a exec_args=(-it)
  [[ -n "$user" ]] && exec_args+=(-u "$user")

  (( $+commands[docker] )) || { print -u2 -r -- "docker-container-sh: docker is not installed"; return 127; }

  # Prefer probing via sh to avoid noisy "executable file not found" errors.
  if command docker exec "${exec_args[@]}" -- "$container" sh -c \
    'if command -v zsh >/dev/null 2>&1; then exec zsh; elif command -v bash >/dev/null 2>&1; then exec bash; else exec sh; fi'
  then
    return 0
  fi

  # Fallback: try direct exec (in case sh is missing).
  command docker exec "${exec_args[@]}" -- "$container" zsh && return 0
  command docker exec "${exec_args[@]}" -- "$container" bash && return 0
  command docker exec "${exec_args[@]}" -- "$container" sh && return 0

  return 1
}

# docker-container-zsh [-u|--user <user>|--root] <container>
# Prefer zsh when available; fallback to bash/sh.
# Usage: docker-container-zsh [-u|--user <user>|--root] <container>
docker-container-zsh() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  docker-container-sh "$@"
}

# docker-container-rm [--no-force] [-v|--volumes] <container...>
# Remove container(s); default is force remove.
# Usage: docker-container-rm [--no-force] [-v|--volumes] <container...>
docker-container-rm() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -A opts=()
  if ! zmodload zsh/zutil 2>/dev/null; then
    print -u2 -r -- "docker-container-rm: zsh/zutil module is required for option parsing"
    return 1
  fi
  zparseopts -D -E -A opts -- h -help v -volumes -no-force

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print -r -- "Usage: docker-container-rm [--no-force] [-v|--volumes] <container...>"
    return 0
  fi

  (( $+commands[docker] )) || { print -u2 -r -- "docker-container-rm: docker is not installed"; return 127; }

  typeset -a args=()
  if (( ${+opts[--no-force]} )); then
    args=()
  else
    args+=(-f)
  fi
  if (( ${+opts[-v]} || ${+opts[--volumes]} )); then
    args+=(-v)
  fi

  if (( $# == 0 )); then
    print -u2 -r -- "Usage: docker-container-rm [--no-force] [-v|--volumes] <container...>"
    return 2
  fi

  command docker container rm "${args[@]}" -- "$@"
}

# docker-compose-down [--all] [--yes] [compose down args...]
# Run docker compose down, optionally removing images/volumes/orphans.
# Usage: docker-compose-down [--all] [--yes] [compose down args...]
# Options:
# - --all: add --remove-orphans --volumes --rmi all
# - -y, --yes: skip confirmation prompts (required for --all in non-interactive shells)
docker-compose-down() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -A opts=()
  if ! zmodload zsh/zutil 2>/dev/null; then
    print -u2 -r -- "docker-compose-down: zsh/zutil module is required for option parsing"
    return 1
  fi
  zparseopts -D -E -A opts -- h -help y -yes a -all

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print -r -- "Usage: docker-compose-down [--all] [--yes] [compose down args...]"
    return 0
  fi

  typeset -a extra=()
  typeset all=false
  typeset yes=false
  (( ${+opts[-a]} || ${+opts[--all]} )) && all=true
  (( ${+opts[-y]} || ${+opts[--yes]} )) && yes=true

  if [[ "$all" == true ]]; then
    extra+=(--remove-orphans --volumes --rmi all)
    if [[ "$yes" != true ]]; then
      if [[ ! -o interactive || ! -t 0 ]]; then
        print -u2 -r -- "docker-compose-down: --all requires --yes in non-interactive shells"
        return 2
      fi
      print -r -- "About to run: docker compose down ${extra[*]} $*"
      print -r -n -- "Proceed? [y/N] "
      typeset reply=''
      read -r reply || return 1
      if [[ "$reply" != [yY] && "$reply" != [yY][eE][sS] ]]; then
        print -r -- "Cancelled."
        return 1
      fi
    fi
  fi

  _docker_compose down "${extra[@]}" "$@"
}

# docker-run-zsh [--no-mount] [--workdir <path>] [--name <name>] [--user <user>] <image>
# Run an interactive container and exec into zsh (fallback bash/sh).
# Usage: docker-run-zsh [--no-mount] [--workdir <path>] [--name <name>] [--user <user>] <image>
docker-run-zsh() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -A opts=()
  if ! zmodload zsh/zutil 2>/dev/null; then
    print -u2 -r -- "docker-run-zsh: zsh/zutil module is required for option parsing"
    return 1
  fi
  zparseopts -D -E -A opts -- h -help -no-mount w: -workdir: n: -name: u: -user: r -root

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print -r -- "Usage: docker-run-zsh [--no-mount] [--workdir <path>] [--name <name>] [--user <user>|--root] <image>"
    return 0
  fi

  typeset image="${1-}"
  if [[ -z "$image" ]]; then
    print -u2 -r -- "Usage: docker-run-zsh [--no-mount] [--workdir <path>] [--name <name>] [--user <user>|--root] <image>"
    return 2
  fi

  (( $+commands[docker] )) || { print -u2 -r -- "docker-run-zsh: docker is not installed"; return 127; }

  typeset mount=true
  (( ${+opts[--no-mount]} )) && mount=false

  typeset workdir=''
  if (( ${+opts[-w]} )); then
    workdir="${opts[-w]}"
  elif (( ${+opts[--workdir]} )); then
    workdir="${opts[--workdir]}"
  elif [[ "$mount" == true ]]; then
    workdir='/work'
  fi

  typeset name=''
  if (( ${+opts[-n]} )); then
    name="${opts[-n]}"
  elif (( ${+opts[--name]} )); then
    name="${opts[--name]}"
  fi

  typeset user=''
  if (( ${+opts[-r]} || ${+opts[--root]} )); then
    user='root'
  elif (( ${+opts[-u]} )); then
    user="${opts[-u]}"
  elif (( ${+opts[--user]} )); then
    user="${opts[--user]}"
  fi

  typeset -a run_args=(--rm -it)
  [[ -n "$name" ]] && run_args+=(--name "$name")
  [[ -n "$user" ]] && run_args+=(-u "$user")
  if [[ "$mount" == true ]]; then
    run_args+=(-v "$PWD:/work")
  fi
  [[ -n "$workdir" ]] && run_args+=(-w "$workdir")

  command docker run "${run_args[@]}" -- "$image" sh -c \
    'if command -v zsh >/dev/null 2>&1; then exec zsh; elif command -v bash >/dev/null 2>&1; then exec bash; else exec sh; fi'
}

# ────────────────────────────────────────────────────────
# docker-tools CLI entrypoint
# ────────────────────────────────────────────────────────
_docker_tools_usage() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  print -r -- "Usage:"
  print -r -- "  docker-tools <group> <command> [args]"
  print -r --
  print -r -- "Groups:"
  print -r -- "  container  sh | zsh | rm"
  print -r -- "  compose    down"
  print -r -- "  run        zsh"
  print -r -- "  alias      list | enable | disable | status"
  print -r --
  print -r -- "Help:"
  print -r -- "  docker-tools help"
  print -r -- "  docker-tools <group> help"
  return 0
}

# _docker_tools_group_usage <group>
# Print `docker-tools <group>` usage.
# Usage: _docker_tools_group_usage <group>
_docker_tools_group_usage() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset group="${1-}"
  case "$group" in
    container)
      print -r -- "Usage: docker-tools container <command> [args]"
      print -r -- "  sh | zsh | rm"
      ;;
    compose)
      print -r -- "Usage: docker-tools compose <command> [args]"
      print -r -- "  down"
      ;;
    run)
      print -r -- "Usage: docker-tools run <command> [args]"
      print -r -- "  zsh"
      ;;
    alias)
      print -r -- "Usage: docker-tools alias <command> [args]"
      print -r -- "  list | enable | disable | status"
      ;;
    *)
      print -u2 -r -- "Unknown group: $group"
      _docker_tools_usage
      return 2
      ;;
  esac
  return 0
}

# docker-tools <group> <command> [args...]
# Dispatcher for docker helper subcommands.
# Usage: docker-tools <group> <command> [args...]
docker-tools() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset group="${1-}"
  typeset cmd="${2-}"

  case "$group" in
    ''|-h|--help|help|list)
      _docker_tools_usage
      return 0
      ;;
  esac

  if [[ -z "$cmd" || "$cmd" == "-h" || "$cmd" == "--help" || "$cmd" == "help" ]]; then
    _docker_tools_group_usage "$group"
    return $?
  fi

  shift 2 || true

  case "$group" in
    container)
      case "$cmd" in
        sh)
          docker-container-sh "$@"
          ;;
        zsh)
          docker-container-zsh "$@"
          ;;
        rm)
          docker-container-rm "$@"
          ;;
        *)
          print -u2 -r -- "Unknown container command: $cmd"
          _docker_tools_group_usage "$group"
          return 2
          ;;
      esac
      ;;
    compose)
      case "$cmd" in
        down)
          docker-compose-down "$@"
          ;;
        *)
          print -u2 -r -- "Unknown compose command: $cmd"
          _docker_tools_group_usage "$group"
          return 2
          ;;
      esac
      ;;
    run)
      case "$cmd" in
        zsh)
          docker-run-zsh "$@"
          ;;
        *)
          print -u2 -r -- "Unknown run command: $cmd"
          _docker_tools_group_usage "$group"
          return 2
          ;;
      esac
      ;;
    alias)
      if ! (( $+functions[docker-aliases] )); then
        print -u2 -r -- "docker-tools: docker-aliases is not loaded (feature init missing?)"
        return 1
      fi
      case "$cmd" in
        list|enable|disable|status)
          docker-aliases "$cmd" "$@"
          ;;
        *)
          print -u2 -r -- "Unknown alias command: $cmd"
          _docker_tools_group_usage "$group"
          return 2
          ;;
      esac
      ;;
    *)
      print -u2 -r -- "Unknown group: $group"
      _docker_tools_usage
      return 2
      ;;
  esac

  return 0
}
