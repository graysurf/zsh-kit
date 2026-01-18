# Host helper to remove a Codex workspace container and its named volumes (feature: codex-workspace).
#
# Usage:
#   codex-workspace-rm <name|container> [--yes]
#
# Notes:
#   - Always uses `docker rm -f` (removes even if running).
#   - Always removes workspace volumes:
#       <container>-work
#       <container>-home
#       <container>-codex-home

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

_codex_workspace_volume_names() {
  emulate -L zsh

  local container="${1:-}"
  [[ -n "$container" ]] || return 1

  print -r -- "${container}-work"
  print -r -- "${container}-home"
  print -r -- "${container}-codex-home"
}

codex-workspace-rm() {
  emulate -L zsh
  setopt pipe_fail

  local name="${1:-}"
  if [[ -z "$name" || "$name" == "-h" || "$name" == "--help" ]]; then
    cat <<'EOF'
usage: codex-workspace-rm <name|container> [--yes]

Remove a workspace container and its named volumes.

Notes:
  - Always runs: docker rm -f <container>
  - Always runs: docker volume rm <container>-work <container>-home <container>-codex-home
  - Add --yes to skip the confirmation prompt.
EOF
    return 0
  fi

  shift 1 2>/dev/null || true

  local want_yes=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes)
        want_yes=1
        shift
        ;;
      -h|--help)
        cat <<'EOF'
usage: codex-workspace-rm <name|container> [--yes]

Remove a workspace container and its named volumes.

Notes:
  - Always runs: docker rm -f <container>
  - Always runs: docker volume rm <container>-work <container>-home <container>-codex-home
  - Add --yes to skip the confirmation prompt.
EOF
        return 0
        ;;
      *)
        print -u2 -r -- "error: unknown arg: $1"
        return 2
        ;;
    esac
  done

  if [[ -z "$name" ]]; then
    print -u2 -r -- "error: missing workspace name/container"
    print -u2 -r -- "hint: codex-workspace-rm <name|container>"
    return 2
  fi

  _codex_workspace_require_docker || return $?

  local container=''
  container="$(_codex_workspace_normalize_container_name "$name")" || return 1

  local -a volumes
  volumes=("${(@f)$(_codex_workspace_volume_names "$container")}")

  if (( !want_yes )); then
    print -r -- "This will REMOVE a workspace:"
    print -r -- "  - container: $container"
    print -r -- "  - volumes:"
    _codex_workspace_print_folders "${volumes[@]}"
    print -r --
    print -r -- "Actions:"
    print -r -- "  - docker rm -f $container"
    print -r -- "  - docker volume rm <volumes...>"
    _codex_workspace_confirm_or_abort "❓ Proceed? [y/N] " || return 1
  fi

  if docker inspect "$container" >/dev/null 2>&1; then
    print -r -- "+ docker rm -f $container"
    docker rm -f "$container" >/dev/null
  else
    print -u2 -r -- "warn: workspace container not found: $container"
  fi

  local -a removed missing failed
  removed=()
  missing=()
  failed=()

  local vol
  for vol in "${volumes[@]}"; do
    if ! docker volume inspect "$vol" >/dev/null 2>&1; then
      missing+=("$vol")
      continue
    fi

    if docker volume rm "$vol" >/dev/null 2>&1; then
      removed+=("$vol")
      continue
    fi

    failed+=("$vol")
  done

  if (( ${#removed[@]} > 0 )); then
    print -r -- "volumes removed:"
    _codex_workspace_print_folders "${removed[@]}"
  fi

  if (( ${#missing[@]} > 0 )); then
    print -r -- "volumes not found (skipped):"
    _codex_workspace_print_folders "${missing[@]}"
  fi

  if (( ${#failed[@]} > 0 )); then
    print -u2 -r -- "error: failed to remove ${#failed[@]} volume(s):"
    local v
    for v in "${failed[@]}"; do
      print -u2 -r -- "  - $v"
    done
    return 1
  fi

  return 0
}

