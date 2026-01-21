# Host helper to remove a Codex workspace container and its named volumes (feature: codex-workspace).
#
# Usage:
#   codex-workspace-rm <name|container> [--yes]
#   codex-workspace-rm --all [--yes]
#
# Notes:
#   - Delegates workspace removal to the codex-kit launcher (canonical).
#   - Removes volumes by default (passes `--volumes` for backwards compatibility).

# _codex_workspace_normalize_container_name <name>
# Normalize a workspace name into a docker container name (adds CODEX_WORKSPACE_PREFIX when needed).
_codex_workspace_normalize_container_name() {
  emulate -L zsh

  local name="${1:-}"
  [[ -n "$name" ]] || return 1

  local prefix="${CODEX_WORKSPACE_PREFIX:-codex-ws}"
  if [[ "$name" == "${prefix}-"* ]]; then
    print -r -- "$name"
    return 0
  fi

  print -r -- "${prefix}-${name}"
  return 0
}

# _codex_workspace_volume_names <container>
# Print the 3 named volumes used by a workspace container (one per line).
_codex_workspace_volume_names() {
  emulate -L zsh

  local container="${1:-}"
  [[ -n "$container" ]] || return 1

  print -r -- "${container}-work"
  print -r -- "${container}-home"
  print -r -- "${container}-codex-home"
}

# _codex_workspace_container_names
# Print detected workspace container names (one per line).
_codex_workspace_container_names() {
  emulate -L zsh
  setopt pipe_fail

  _codex_workspace_require_docker || return $?

  local -a names=()
  names=(${(f)"$(docker ps -a --filter 'label=codex-kit.workspace=1' --format '{{.Names}}' 2>/dev/null || true)"})

  if (( ${#names[@]} == 0 )); then
    local prefix="${CODEX_WORKSPACE_PREFIX:-codex-ws}"
    names=(${(f)"$(docker ps -a --format '{{.Names}}' 2>/dev/null || true)"})

    local -a filtered=()
    local name=''
    for name in "${names[@]}"; do
      [[ "$name" == "${prefix}-"* ]] || continue
      filtered+=("$name")
    done
    names=("${filtered[@]}")
  fi

  local name=''
  for name in "${names[@]}"; do
    [[ -n "$name" ]] || continue
    print -r -- "$name"
  done

  return 0
}

# _codex_workspace_resolve_launcher_for_callthrough
# Resolve an executable launcher path for call-through commands (ls/rm).
_codex_workspace_resolve_launcher_for_callthrough() {
  emulate -L zsh
  setopt pipe_fail

  local launcher="${CODEX_WORKSPACE_LAUNCHER-}"
  local -i launcher_explicit=0
  if [[ -n "${launcher//[[:space:]]/}" ]]; then
    launcher_explicit=1
  else
    if (( $+functions[_codex_workspace_launcher_default_path] )); then
      launcher="$(_codex_workspace_launcher_default_path)"
    else
      launcher="$HOME/.config/codex-kit/docker/codex-env/bin/codex-workspace"
    fi
  fi

  if (( $+functions[_codex_workspace_ensure_launcher] )); then
    launcher="$(_codex_workspace_ensure_launcher "$launcher" "$launcher_explicit")" || {
      if (( launcher_explicit )); then
        return 1
      fi
      print -u2 -r -- "hint: set CODEX_WORKSPACE_LAUNCHER to a local launcher path"
      print -u2 -r -- "hint: or set CODEX_WORKSPACE_LAUNCHER_URL to override the download URL"
      return 1
    }
  else
    if [[ ! -x "$launcher" ]]; then
      print -u2 -r -- "error: launcher not found or not executable: $launcher"
      return 1
    fi
  fi

  print -r -- "$launcher"
  return 0
}

# codex-workspace-list
# List workspace containers (one per line).
codex-workspace-list() {
  emulate -L zsh
  setopt pipe_fail

  if (( $# > 1 )); then
    print -u2 -r -- "error: unexpected args: $*"
    return 2
  fi

  local arg1="${1:-}"
  if [[ -n "$arg1" && "$arg1" != "-h" && "$arg1" != "--help" ]]; then
    print -u2 -r -- "error: unknown arg: $arg1"
    return 2
  fi

  if [[ "$arg1" == "-h" || "$arg1" == "--help" ]]; then
    cat <<'EOF'
usage: codex-workspace ls

List workspace containers (one per line).
EOF
    return 0
  fi

  _codex_workspace_require_docker || return $?
  if ! docker info >/dev/null 2>&1; then
    print -u2 -r -- "error: docker daemon not running (start OrbStack/Docker Desktop)"
    return 1
  fi

  local launcher=''
  launcher="$(_codex_workspace_resolve_launcher_for_callthrough)" || return $?

  "$launcher" ls
  return $?
}

# _codex_workspace_rm_one <launcher> <name|container> [--yes]
# Remove a single workspace container and its named volumes (delegates to launcher).
_codex_workspace_rm_one() {
  emulate -L zsh
  setopt pipe_fail

  local launcher="${1:-}"
  local name="${2:-}"
  local -i want_yes="${3:-0}"

  if [[ -z "$launcher" || ! -x "$launcher" ]]; then
    print -u2 -r -- "error: launcher not found or not executable: $launcher"
    return 1
  fi

  if [[ -z "$name" ]]; then
    print -u2 -r -- "error: missing workspace name/container"
    print -u2 -r -- "hint: codex-workspace rm <name|container> [--yes]"
    return 2
  fi

  local container=''
  container="$(_codex_workspace_normalize_container_name "$name")" || return 1

  if (( !want_yes )); then
    print -r -- "This will REMOVE a workspace:"
    print -r -- "  - container: $container"
    print -r --
    print -r -- "Actions:"
    print -r -- "  - $launcher rm $container --volumes"
    _codex_workspace_confirm_or_abort "❓ Proceed? [y/N] " || return 1
  fi

  print -r -- "+ $launcher rm $container --volumes"
  "$launcher" rm "$container" --volumes

  return $?
}

# codex-workspace-rm <name|container> [--yes]
# codex-workspace-rm --all [--yes]
# Remove workspace container(s) and their named volumes.
codex-workspace-rm() {
  emulate -L zsh
  setopt pipe_fail

  if (( $# == 0 )); then
    cat <<'EOF'
usage:
  codex-workspace-rm <name|container> [--yes]
  codex-workspace-rm --all [--yes]

Remove workspace container(s) and their named volumes.

Notes:
  - Delegates to the codex-kit launcher: <launcher> rm <container> --volumes
  - Add --yes to skip the confirmation prompt.
EOF
    return 0
  fi

  local -i want_all=0
  local -i want_yes=0
  local -i want_help=0
  local name=''
  local -a extra_args=()

  while (( $# > 0 )); do
    case "$1" in
      -h|--help)
        want_help=1
        shift
        ;;
      --all)
        want_all=1
        shift
        ;;
      -y|--yes)
        want_yes=1
        shift
        ;;
      --)
        shift
        while (( $# > 0 )); do
          if [[ -z "$name" ]]; then
            name="$1"
          else
            extra_args+=("$1")
          fi
          shift
        done
        ;;
      -*)
        print -u2 -r -- "error: unknown option: $1"
        return 2
        ;;
      *)
        if [[ -z "$name" ]]; then
          name="$1"
        else
          extra_args+=("$1")
        fi
        shift
        ;;
    esac
  done

  if (( want_help )); then
    cat <<'EOF'
usage:
  codex-workspace-rm <name|container> [--yes]
  codex-workspace-rm --all [--yes]

Remove workspace container(s) and their named volumes.

Notes:
  - Always runs: docker rm -f <container>
  - Always runs: docker volume rm <container>-work <container>-home <container>-codex-home
  - Add --yes to skip the confirmation prompt.
EOF
    return 0
  fi

  if (( ${#extra_args[@]} > 0 )); then
    print -u2 -r -- "error: unexpected extra args: ${extra_args[*]}"
    return 2
  fi

  _codex_workspace_require_docker || return $?
  if ! docker info >/dev/null 2>&1; then
    print -u2 -r -- "error: docker daemon not running (start OrbStack/Docker Desktop)"
    return 1
  fi

  local launcher=''
  launcher="$(_codex_workspace_resolve_launcher_for_callthrough)" || return $?

  if (( want_all )); then
    if [[ -n "$name" ]]; then
      print -u2 -r -- "error: cannot combine --all with a workspace name"
      return 2
    fi

    local ls_out=''
    ls_out="$("$launcher" ls)" || return $?

    local -a containers=()
    local line=''
    for line in "${(@f)ls_out}"; do
      [[ -n "$line" ]] || continue
      containers+=("${line%%$'\t'*}")
    done
    if (( ${#containers[@]} == 0 )); then
      print -u2 -r -- "no workspaces found"
      return 0
    fi

    if (( !want_yes )); then
      print -r -- "This will REMOVE ${#containers[@]} workspace(s):"
      _codex_workspace_print_folders "${containers[@]}"
      print -r --
      print -r -- "Actions (per workspace): $launcher rm <container> --volumes"
      _codex_workspace_confirm_or_abort "❓ Proceed? [y/N] " || return 1
    fi

    local -i rc=0
    local container=''
    for container in "${containers[@]}"; do
      _codex_workspace_rm_one "$launcher" "$container" 1 || rc=1
    done
    return $rc
  fi

  if [[ -z "$name" ]]; then
    print -u2 -r -- "error: missing workspace name/container"
    print -u2 -r -- "hint: codex-workspace rm <name|container> [--yes]"
    return 2
  fi

  _codex_workspace_rm_one "$launcher" "$name" "$want_yes"
  return $?
}
