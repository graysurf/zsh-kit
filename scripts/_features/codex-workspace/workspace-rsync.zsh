# Host helper to rsync files between the host and a Codex workspace container (feature: codex-workspace).
#
# Usage:
#   codex-workspace rsync push [options] [<name|container>] <host_src> <container_dest> [<rsync_args...>]
#   codex-workspace rsync pull [options] [<name|container>] <container_src> <host_dest> [<rsync_args...>]
#
# Notes:
#   - The container arg is optional when only one workspace exists.
#   - Pass additional rsync flags after the src/dest paths; this wrapper will place them before the paths.
#   - Requires `rsync` on the host and inside the container.
#   - Uses `docker exec` as the rsync remote shell (no SSH needed).

# _codex_workspace_rsync_usage
# Print help for `codex-workspace rsync`.
_codex_workspace_rsync_usage() {
  emulate -L zsh

  cat <<'EOF'
usage:
  codex-workspace rsync push [--user <user>|--root] [--delete] [--dry-run] [<name|container>] <host_src> <container_dest> [<rsync_args...>]
  codex-workspace rsync pull [--user <user>|--root] [--delete] [--dry-run] [<name|container>] <container_src> <host_dest> [<rsync_args...>]

examples:
  # push ./data -> /work/data (auto-picks the only workspace)
  codex-workspace rsync push ./data/ /work/data/

  # pull /work/repo -> ./repo (explicit container)
  codex-workspace rsync pull ws-foo /work/repo/ ./repo/

  # pass rsync filters/options (placed before paths)
  codex-workspace rsync push ws-foo ./src/ /work/src/ --exclude '.git' --delete

notes:
  - Requires `rsync` on the host and inside the container.
  - Uses `docker exec` as the rsync remote shell (no SSH needed).
EOF

  return 0
}

# _codex_workspace_rsync_mktemp
# Create a temporary executable file and print its path.
_codex_workspace_rsync_mktemp() {
  emulate -L zsh

  local tmp=''
  tmp="$(mktemp "${TMPDIR:-/tmp}/codex-workspace-rsync-rsh.XXXXXX" 2>/dev/null || true)"
  if [[ -z "$tmp" ]]; then
    tmp="$(mktemp -t codex-workspace-rsync-rsh.XXXXXX 2>/dev/null || true)"
  fi
  if [[ -z "$tmp" ]]; then
    print -u2 -r -- "error: mktemp failed (rsync remote shell wrapper)"
    return 1
  fi

  print -r -- "$tmp"
  return 0
}

# codex-workspace-rsync <push|pull> [options] [<name|container>] <src> <dest> [rsync_args...]
# Sync files between the host and a workspace container using rsync-over-docker-exec.
codex-workspace-rsync() {
  emulate -L zsh
  setopt pipe_fail

  if (( $# == 0 )); then
    _codex_workspace_rsync_usage
    return 0
  fi

  local subcmd="${1:-}"
  case "$subcmd" in
    -h|--help|help)
      _codex_workspace_rsync_usage
      return 0
      ;;
    push|pull)
      shift 1 2>/dev/null || true
      ;;
    *)
      print -u2 -r -- "error: unknown rsync subcommand: $subcmd"
      print -u2 -r -- "hint: expected: push|pull"
      _codex_workspace_rsync_usage
      return 2
      ;;
  esac

  local -i want_help=0
  local -i want_delete=0
  local -i want_dry_run=0
  local -i want_root=0
  local user='codex'

  while (( $# > 0 )); do
    case "$1" in
      -h|--help)
        want_help=1
        shift
        ;;
      --delete)
        want_delete=1
        shift
        ;;
      -n|--dry-run)
        want_dry_run=1
        shift
        ;;
      --root)
        want_root=1
        shift
        ;;
      -u|--user)
        user="${2:-}"
        if [[ -z "${user//[[:space:]]/}" ]]; then
          print -u2 -r -- "error: $1 requires a value"
          return 2
        fi
        shift 2 2>/dev/null || true
        ;;
      --user=*)
        user="${1#*=}"
        if [[ -z "${user//[[:space:]]/}" ]]; then
          print -u2 -r -- "error: --user requires a value"
          return 2
        fi
        shift
        ;;
      --)
        print -u2 -r -- "error: unexpected -- (pass rsync flags after the src/dest paths)"
        return 2
        ;;
      -*)
        print -u2 -r -- "error: unknown option: $1"
        print -u2 -r -- "hint: pass rsync flags after the src/dest paths"
        return 2
        ;;
      *)
        break
        ;;
    esac
  done

  if (( want_help )); then
    _codex_workspace_rsync_usage
    return 0
  fi

  if (( want_root )); then
    user='root'
  fi

  if ! command -v rsync >/dev/null 2>&1; then
    print -u2 -r -- "error: rsync not found on host"
    return 1
  fi

  local -a rest=()
  rest=("$@")
  if (( ${#rest[@]} < 2 )); then
    print -u2 -r -- "error: missing args"
    _codex_workspace_rsync_usage
    return 2
  fi

  local container_arg='' src='' dest=''
  local -a rsync_args=()

  if (( ${#rest[@]} == 2 )); then
    container_arg=''
    src="${rest[1]}"
    dest="${rest[2]}"
    rsync_args=()
  else
    # Heuristic:
    # - If arg3 looks like an option (starts with -), treat as "no container" mode:
    #     <src> <dest> <rsync_args...>
    # - Otherwise treat as:
    #     <name|container> <src> <dest> <rsync_args...>
    if [[ "${rest[3]-}" == -* ]]; then
      container_arg=''
      src="${rest[1]}"
      dest="${rest[2]}"
      rsync_args=("${rest[@]:2}")
    else
      container_arg="${rest[1]}"
      src="${rest[2]}"
      dest="${rest[3]}"
      rsync_args=("${rest[@]:3}")
    fi
  fi

  if (( $+functions[_codex_workspace_resolve_container] )); then
    local container=''
    container="$(_codex_workspace_resolve_container "$container_arg")" || return $?

    if (( $+functions[_codex_workspace_ensure_container_running] )); then
      _codex_workspace_ensure_container_running "$container" || return $?
    fi

    if ! docker exec -u "$user" "$container" rsync --version >/dev/null 2>&1; then
      print -u2 -r -- "error: rsync not available in container: $container (user: $user)"
      print -u2 -r -- "hint: install rsync in the container image"
      return 1
    fi

    local rsh=''
    rsh="$(_codex_workspace_rsync_mktemp)" || return $?

    cat >| "$rsh" <<'EOF'
#!/bin/sh
set -eu

container="${CODEX_WORKSPACE_RSYNC_CONTAINER:?missing CODEX_WORKSPACE_RSYNC_CONTAINER}"
user="${CODEX_WORKSPACE_RSYNC_USER:-codex}"

# rsync remote-shell invocation:
#   <rsh> [opts...] <host> <command...>
# Some variants include: -l <user> <host>
while [ $# -gt 0 ]; do
  case "$1" in
    -l)
      shift 2
      ;;
    --*)
      shift
      ;;
    -*)
      shift
      ;;
    *)
      shift # host
      break
      ;;
  esac
done

exec docker exec -u "$user" -i "$container" "$@"
EOF

    chmod 700 "$rsh" 2>/dev/null || true

    local -a cmd=()
    cmd=(rsync -rlpt --partial --progress -e "$rsh")

    if (( want_delete )); then
      cmd+=(--delete)
    fi
    if (( want_dry_run )); then
      cmd+=(--dry-run)
    fi

    cmd+=("${rsync_args[@]}")

    if [[ "$subcmd" == "push" ]]; then
      cmd+=("$src" "${container}:${dest}")
    else
      cmd+=("${container}:${src}" "$dest")
    fi

    print -r -- "+ ${cmd[*]}"
    local rc=0
    CODEX_WORKSPACE_RSYNC_CONTAINER="$container" CODEX_WORKSPACE_RSYNC_USER="$user" "${cmd[@]}"
    rc=$?
    rm -f -- "$rsh" 2>/dev/null || true
    return $rc
  fi

  print -u2 -r -- "error: codex-workspace rsync requires codex-workspace feature loaded"
  return 1
}
