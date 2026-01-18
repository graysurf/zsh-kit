# ────────────────────────────────────────────────────────
# docker aliases (feature: docker)
# ────────────────────────────────────────────────────────

typeset -g -a _ZSH_DOCKER_ALIAS_SETS_ENABLED=()

if ! (( $+functions[_docker_compose] )); then
  # Fallback for sourcing docker-aliases.zsh standalone (without docker-tools).
  _docker_compose() {
    emulate -L zsh
    setopt pipe_fail err_return nounset

    if (( $+commands[docker-compose] )); then
      command docker-compose "$@"
      return $?
    fi
    if (( $+commands[docker] )); then
      command docker compose "$@"
      return $?
    fi
    print -u2 -r -- "_docker_compose: docker is not installed"
    return 127
  }
fi

# _docker_aliases::_available_sets
# Print supported alias set names.
# Usage: _docker_aliases::_available_sets
_docker_aliases::_available_sets() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  print -r -- "base"
  print -r -- "omz"
  print -r -- "long"
}

# _docker_aliases::_has_set <name>
# Return 0 if the set exists.
# Usage: _docker_aliases::_has_set <name>
_docker_aliases::_has_set() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset name="${1-}"
  [[ -n "$name" ]] || return 1
  case "$name" in
    base|omz|long) return 0 ;;
  esac
  return 1
}

# _docker_aliases::_set_is_enabled <name>
# Return 0 if the set is currently enabled.
# Usage: _docker_aliases::_set_is_enabled <name>
_docker_aliases::_set_is_enabled() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset name="${1-}"
  [[ -n "$name" ]] || return 1
  (( ${_ZSH_DOCKER_ALIAS_SETS_ENABLED[(Ie)$name]} > 0 ))
}

# _docker_aliases::_enable_set_base
# Enable minimal Docker aliases.
# Usage: _docker_aliases::_enable_set_base
_docker_aliases::_enable_set_base() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if command -v safe_unalias >/dev/null; then
    safe_unalias d dc dt dsh drz
  fi

  # d: docker
  alias d='docker'
  # dc: docker compose wrapper
  alias dc='_docker_compose'
  # dt: docker-tools
  alias dt='docker-tools'
  # dsh: exec best shell in a container
  alias dsh='docker-tools container sh'
  # drz: run image and exec best shell
  alias drz='docker-tools run zsh'

  return 0
}

# _docker_aliases::_enable_set_omz
# Enable oh-my-zsh style Docker/Compose aliases.
# Usage: _docker_aliases::_enable_set_omz
_docker_aliases::_enable_set_omz() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if command -v safe_unalias >/dev/null; then
    safe_unalias \
      dbl dcin dcls dclsa dib dii dils dipu dipru dirm dit dlo dnc dncn dndcn dni dnls dnrm dpo dps dpsa dpu \
      dr drit drm 'drm!' dst drs dsta dstp dsts dtop dvi dvls dvprune dxc dxcit \
      dco dcb dce dcps dcrestart dcrm dcr dcstop dcup dcupb dcupd dcupdb dcdn dcl dclf dclF dcpull dcstart dck
  fi

  # Docker (oh-my-zsh style)
  # dbl: docker build
  alias dbl='docker build'
  # dcin: docker container inspect
  alias dcin='docker container inspect'
  # dcls: docker container ls
  alias dcls='docker container ls'
  # dclsa: docker container ls -a
  alias dclsa='docker container ls -a'
  # dib: docker image build
  alias dib='docker image build'
  # dii: docker image inspect
  alias dii='docker image inspect'
  # dils: docker image ls
  alias dils='docker image ls'
  # dipu: docker image push
  alias dipu='docker image push'
  # dipru: docker image prune -a
  alias dipru='docker image prune -a'
  # dirm: docker image rm
  alias dirm='docker image rm'
  # dit: docker image tag
  alias dit='docker image tag'
  # dlo: docker container logs
  alias dlo='docker container logs'
  # dnc: docker network create
  alias dnc='docker network create'
  # dncn: docker network connect
  alias dncn='docker network connect'
  # dndcn: docker network disconnect
  alias dndcn='docker network disconnect'
  # dni: docker network inspect
  alias dni='docker network inspect'
  # dnls: docker network ls
  alias dnls='docker network ls'
  # dnrm: docker network rm
  alias dnrm='docker network rm'
  # dpo: docker container port
  alias dpo='docker container port'
  # dps: docker ps
  alias dps='docker ps'
  # dpsa: docker ps -a
  alias dpsa='docker ps -a'
  # dpu: docker pull
  alias dpu='docker pull'
  # dr: docker container run
  alias dr='docker container run'
  # drit: docker container run -it
  alias drit='docker container run -it'
  # drm: docker container rm
  alias drm='docker container rm'
  # drm!: docker container rm -f
  alias 'drm!'='docker container rm -f'
  # dst: docker container start
  alias dst='docker container start'
  # drs: docker container restart
  alias drs='docker container restart'
  # dsta: stop all running containers
  alias dsta='docker stop $(docker ps -q)'
  # dstp: docker container stop
  alias dstp='docker container stop'
  # dsts: docker stats
  alias dsts='docker stats'
  # dtop: docker top
  alias dtop='docker top'
  # dvi: docker volume inspect
  alias dvi='docker volume inspect'
  # dvls: docker volume ls
  alias dvls='docker volume ls'
  # dvprune: docker volume prune
  alias dvprune='docker volume prune'
  # dxc: docker container exec
  alias dxc='docker container exec'
  # dxcit: docker container exec -it
  alias dxcit='docker container exec -it'

  # Compose (oh-my-zsh docker-compose style; uses _docker_compose wrapper)
  # dco: docker compose
  alias dco='_docker_compose'
  # dcb: docker compose build
  alias dcb='_docker_compose build'
  # dce: docker compose exec
  alias dce='_docker_compose exec'
  # dcps: docker compose ps
  alias dcps='_docker_compose ps'
  # dcrestart: docker compose restart
  alias dcrestart='_docker_compose restart'
  # dcrm: docker compose rm
  alias dcrm='_docker_compose rm'
  # dcr: docker compose run
  alias dcr='_docker_compose run'
  # dcstop: docker compose stop
  alias dcstop='_docker_compose stop'
  # dcup: docker compose up
  alias dcup='_docker_compose up'
  # dcupb: docker compose up --build
  alias dcupb='_docker_compose up --build'
  # dcupd: docker compose up -d
  alias dcupd='_docker_compose up -d'
  # dcupdb: docker compose up -d --build
  alias dcupdb='_docker_compose up -d --build'
  # dcdn: docker compose down
  alias dcdn='_docker_compose down'
  # dcl: docker compose logs
  alias dcl='_docker_compose logs'
  # dclf: docker compose logs -f
  alias dclf='_docker_compose logs -f'
  # dclF: docker compose logs -f --tail 0
  alias dclF='_docker_compose logs -f --tail 0'
  # dcpull: docker compose pull
  alias dcpull='_docker_compose pull'
  # dcstart: docker compose start
  alias dcstart='_docker_compose start'
  # dck: docker compose kill
  alias dck='_docker_compose kill'

  return 0
}

# _docker_aliases::_enable_set_long
# Enable verbose Docker aliases.
# Usage: _docker_aliases::_enable_set_long
_docker_aliases::_enable_set_long() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  if command -v safe_unalias >/dev/null; then
    safe_unalias \
      docker-ps docker-psa docker-images docker-image-ls docker-container-ls docker-container-lsa docker-logs \
      docker-exec docker-execit docker-run docker-runit docker-rm docker-rmf docker-pull docker-build \
      docker-system-prune docker-volume-prune docker-image-prune
  fi

  # docker-ps: docker ps
  alias docker-ps='docker ps'
  # docker-psa: docker ps -a
  alias docker-psa='docker ps -a'
  # docker-images: docker image ls
  alias docker-images='docker image ls'
  # docker-image-ls: docker image ls
  alias docker-image-ls='docker image ls'
  # docker-container-ls: docker container ls
  alias docker-container-ls='docker container ls'
  # docker-container-lsa: docker container ls -a
  alias docker-container-lsa='docker container ls -a'
  # docker-logs: docker logs
  alias docker-logs='docker logs'
  # docker-exec: docker exec
  alias docker-exec='docker exec'
  # docker-execit: docker exec -it
  alias docker-execit='docker exec -it'
  # docker-run: docker run
  alias docker-run='docker run'
  # docker-runit: docker run -it
  alias docker-runit='docker run -it'
  # docker-rm: docker rm
  alias docker-rm='docker rm'
  # docker-rmf: docker rm -f
  alias docker-rmf='docker rm -f'
  # docker-pull: docker pull
  alias docker-pull='docker pull'
  # docker-build: docker build
  alias docker-build='docker build'
  # docker-system-prune: docker system prune
  alias docker-system-prune='docker system prune'
  # docker-volume-prune: docker volume prune
  alias docker-volume-prune='docker volume prune'
  # docker-image-prune: docker image prune
  alias docker-image-prune='docker image prune'

  return 0
}

# _docker_aliases::_disable_set <name>
# Disable a set by removing its aliases.
# Usage: _docker_aliases::_disable_set <name>
_docker_aliases::_disable_set() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset name="${1-}"
  _docker_aliases::_has_set "$name" || return 2

  if command -v safe_unalias >/dev/null; then
    case "$name" in
      base)
        safe_unalias d dc dt dsh drz
        ;;
      omz)
        safe_unalias \
          dbl dcin dcls dclsa dib dii dils dipu dipru dirm dit dlo dnc dncn dndcn dni dnls dnrm dpo dps dpsa dpu \
          dr drit drm 'drm!' dst drs dsta dstp dsts dtop dvi dvls dvprune dxc dxcit \
          dco dcb dce dcps dcrestart dcrm dcr dcstop dcup dcupb dcupd dcupdb dcdn dcl dclf dclF dcpull dcstart dck
        ;;
      long)
        safe_unalias \
          docker-ps docker-psa docker-images docker-image-ls docker-container-ls docker-container-lsa docker-logs \
          docker-exec docker-execit docker-run docker-runit docker-rm docker-rmf docker-pull docker-build \
          docker-system-prune docker-volume-prune docker-image-prune
        ;;
    esac
  fi

  _ZSH_DOCKER_ALIAS_SETS_ENABLED=(${_ZSH_DOCKER_ALIAS_SETS_ENABLED:#$name})
  return 0
}

# _docker_aliases::_enable_set <name>
# Enable one set by name.
# Usage: _docker_aliases::_enable_set <name>
_docker_aliases::_enable_set() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset name="${1-}"
  _docker_aliases::_has_set "$name" || return 2

  _docker_aliases::_disable_set "$name" >/dev/null 2>&1 || true

  case "$name" in
    base) _docker_aliases::_enable_set_base ;;
    omz) _docker_aliases::_enable_set_omz ;;
    long) _docker_aliases::_enable_set_long ;;
  esac

  if ! _docker_aliases::_set_is_enabled "$name"; then
    _ZSH_DOCKER_ALIAS_SETS_ENABLED+=("$name")
  fi

  return 0
}

# _docker_aliases::_resolve_default_sets
# Resolve default sets from `ZSH_DOCKER_ALIASES`.
# Usage: _docker_aliases::_resolve_default_sets
_docker_aliases::_resolve_default_sets() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset raw="${ZSH_DOCKER_ALIASES-}"
  raw="${raw:l}"
  raw="${raw//[[:space:]]/}"

  if [[ -z "$raw" ]]; then
    print -r -- "base,omz,long"
    return 0
  fi

  case "$raw" in
    all) print -r -- "base,omz,long" ;;
    none|off|0) print -r -- "" ;;
    *) print -r -- "$raw" ;;
  esac
}

# docker-aliases <action> [...]
# Manage docker alias sets (enable/disable/list/status).
# Usage: docker-aliases list|status|enable|disable|init
docker-aliases() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset action="${1-}"
  shift || true

  case "$action" in
    ''|-h|--help|help)
      print -r -- "Usage:"
      print -r -- "  docker-aliases list"
      print -r -- "  docker-aliases status"
      print -r -- "  docker-aliases enable <set...>"
      print -r -- "  docker-aliases disable <set...>"
      print -r --
      print -r -- "Sets:"
      print -r -- "  base   d/dc/dt/dsh/drz"
      print -r -- "  omz    dps/dxcit/dcup/... (oh-my-zsh style)"
      print -r -- "  long   docker-ps/docker-execit/... (verbose)"
      print -r --
      print -r -- "Env:"
      print -r -- "  ZSH_DOCKER_ALIASES=base,omz,long|all|none"
      print -r -- "  ZSH_DOCKER_COMPOSE_CMD='docker compose' (override compose command)"
      return 0
      ;;
    list)
      _docker_aliases::_available_sets
      return 0
      ;;
    status)
      print -r -- "Enabled sets: ${_ZSH_DOCKER_ALIAS_SETS_ENABLED[*]-}"
      if (( $+functions[_docker_compose_resolve_cmd] )); then
        _docker_compose_resolve_cmd >/dev/null 2>&1 || true
        if (( ${#_ZSH_DOCKER_COMPOSE_CMD_CACHE[@]} > 0 )); then
          print -r -- "Compose cmd: ${_ZSH_DOCKER_COMPOSE_CMD_CACHE[*]}"
        fi
      fi
      return 0
      ;;
    enable)
      if (( $# == 0 )); then
        print -u2 -r -- "docker-aliases enable: missing set"
        return 2
      fi
      if [[ "$1" == "all" ]]; then
        _docker_aliases::_enable_set base
        _docker_aliases::_enable_set omz
        _docker_aliases::_enable_set long
        return 0
      fi
      typeset arg='' set=''
      for arg in "$@"; do
        for set in ${(s:,:)arg}; do
          [[ -n "$set" ]] || continue
          _docker_aliases::_enable_set "$set" || return $?
        done
      done
      return 0
      ;;
    disable)
      if (( $# == 0 )); then
        print -u2 -r -- "docker-aliases disable: missing set"
        return 2
      fi
      if [[ "$1" == "all" || "$1" == "none" ]]; then
        _docker_aliases::_disable_set base || true
        _docker_aliases::_disable_set omz || true
        _docker_aliases::_disable_set long || true
        return 0
      fi
      typeset arg='' set=''
      for arg in "$@"; do
        for set in ${(s:,:)arg}; do
          [[ -n "$set" ]] || continue
          _docker_aliases::_disable_set "$set" || return $?
        done
      done
      return 0
      ;;
    init)
      typeset resolved="$(_docker_aliases::_resolve_default_sets)"
      [[ -n "$resolved" ]] || return 0
      typeset -a sets=(${(s:,:)resolved})
      typeset set=''
      for set in "${sets[@]}"; do
        [[ -n "$set" ]] || continue
        _docker_aliases::_enable_set "$set" || return $?
      done
      return 0
      ;;
    *)
      print -u2 -r -- "docker-aliases: unknown action: $action"
      return 2
      ;;
  esac
}

# Auto-enable aliases on feature load unless explicitly disabled.
if [[ "${ZSH_DOCKER_ALIASES_AUTO:-1}" -ne 0 ]]; then
  docker-aliases init >/dev/null 2>&1 || true
fi
