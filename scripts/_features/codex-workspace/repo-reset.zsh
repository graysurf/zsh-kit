# Repo reset helpers for Codex workspace containers (feature: codex-workspace).
#
# Public functions:
#   - codex-workspace-reset <subcommand> [args...]
#   - codex-workspace-refresh-opt-repos <container> [--yes]
#   - codex-workspace-reset-repo <container> <repo_dir> [--ref <remote/branch>] [--yes]
#   - codex-workspace-reset-private-repo <container> [--ref <remote/branch>] [--yes]
#   - codex-workspace-reset-work-repos <container> [--root <dir>] [--depth <N>] [--ref <remote/branch>] [--yes]

# _codex_workspace_confirm <prompt>
# Prompt for y/N confirmation (returns 0 only on "y"/"Y").
_codex_workspace_confirm() {
  emulate -L zsh

  local prompt="${1-}"
  [[ -n "$prompt" ]] || return 1
  shift || true

  print -n -r -- "$prompt"

  local confirm=''
  IFS= read -r confirm
  [[ "$confirm" == [yY] ]]
}

# _codex_workspace_confirm_or_abort <prompt>
# Prompt for confirmation; print "Aborted" and return non-zero on decline.
_codex_workspace_confirm_or_abort() {
  _codex_workspace_confirm "$@" && return 0
  print -r -- "🚫 Aborted"
  return 1
}

# _codex_workspace_print_folders [paths...]
# Print a bullet list of folders/paths.
_codex_workspace_print_folders() {
  emulate -L zsh

  local folder
  for folder in "$@"; do
    print -r -- "  - $folder"
  done
}

# _codex_workspace_require_docker
# Ensure `docker` is available on the host.
_codex_workspace_require_docker() {
  emulate -L zsh

  if ! command -v docker >/dev/null 2>&1; then
    print -u2 -r -- "error: docker not found on host"
    return 1
  fi
  return 0
}

# _codex_workspace_require_container <container>
# Ensure the workspace container exists on the host.
_codex_workspace_require_container() {
  emulate -L zsh

  local container="${1:-}"
  if [[ -z "$container" ]]; then
    print -u2 -r -- "error: missing container name"
    return 2
  fi

  if ! docker inspect "$container" >/dev/null 2>&1; then
    print -u2 -r -- "error: workspace container not found: $container"
    return 1
  fi
  return 0
}

# _codex_workspace_container_reset_repo <container> <repo_dir> [ref]
# Reset a repo inside a workspace container to a remote-tracking ref.
_codex_workspace_container_reset_repo() {
  emulate -L zsh
  setopt pipe_fail

  local container="${1:?missing container}"
  local repo_dir="${2:?missing repo_dir}"
  local ref="${3:-origin/main}"

  docker exec -i -u codex "$container" zsh -s -- "$repo_dir" "$ref" <<'EOF'
set -euo pipefail

repo_dir="${1:?missing repo_dir}"
ref="${2:-origin/main}"

# _load_git_reset_remote
# Load git-reset-remote when available (preferred: function, fallback: zsh-kit file).
_load_git_reset_remote() {
  if typeset -f git-reset-remote >/dev/null 2>&1; then
    return 0
  fi
  if [[ -f /opt/zsh-kit/scripts/git/tools/git-reset.zsh ]]; then
    source /opt/zsh-kit/scripts/git/tools/git-reset.zsh
    return 0
  fi
  return 1
}

# _resolve_target_ref <remote/branch>
# Resolve and validate a remote-tracking ref (fallbacks: remote/HEAD, then remote/master).
_resolve_target_ref() {
  local ref="$1"
  local remote="${ref%%/*}"
  local branch="${ref#*/}"

  if [[ "$remote" == "$ref" || -z "$remote" || -z "$branch" ]]; then
    print -u2 -r -- "error: invalid ref (expected remote/branch): $ref"
    return 2
  fi

  # Ensure remote-tracking branches are up-to-date.
  git fetch --prune -- "$remote" >/dev/null 2>&1 || git fetch --prune -- "$remote"

  if git show-ref --verify --quiet "refs/remotes/$remote/$branch"; then
    print -r -- "$remote/$branch"
    return 0
  fi

  # Fallback: use remote HEAD if set.
  local default_ref=''
  default_ref="$(git symbolic-ref -q --short "refs/remotes/$remote/HEAD" 2>/dev/null || true)"
  local default_branch="${default_ref#${remote}/}"
  if [[ -n "$default_branch" && "$default_branch" != "$default_ref" ]]; then
    if git show-ref --verify --quiet "refs/remotes/$remote/$default_branch"; then
      print -u2 -r -- "warn: $remote/$branch not found; using $remote/$default_branch (from $remote/HEAD)"
      print -r -- "$remote/$default_branch"
      return 0
    fi
  fi

  if git show-ref --verify --quiet "refs/remotes/$remote/master"; then
    print -u2 -r -- "warn: $remote/$branch not found; using $remote/master"
    print -r -- "$remote/master"
    return 0
  fi

  print -u2 -r -- "error: remote branch not found: $remote/$branch"
  return 1
}

# _force_checkout_branch <branch> [start_point]
# Force checkout a branch, cleaning untracked files if needed.
_force_checkout_branch() {
  local branch="$1"
  local start_point="${2:-}"

  if [[ -n "$start_point" ]]; then
    git checkout --force -B "$branch" "$start_point" >/dev/null 2>&1 && return 0
    git clean -fd >/dev/null 2>&1 || true
    git checkout --force -B "$branch" "$start_point"
    return $?
  fi

  git checkout --force "$branch" >/dev/null 2>&1 && return 0
  git clean -fd >/dev/null 2>&1 || true
  git checkout --force "$branch"
}

# _reset_repo_to_ref <repo_dir> <remote/branch>
# Reset a repo dir to the resolved remote-tracking ref (hard reset + clean).
_reset_repo_to_ref() {
  local repo_dir="$1"
  local ref="$2"

  if [[ ! -e "$repo_dir/.git" ]]; then
    print -u2 -r -- "error: not a git repo: $repo_dir"
    return 1
  fi

  cd "$repo_dir"

  local resolved_ref=''
  resolved_ref="$(_resolve_target_ref "$ref")" || return $?

  local branch="${resolved_ref#*/}"

  print -r -- "+ reset $repo_dir -> $resolved_ref"

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    _force_checkout_branch "$branch"
  else
    _force_checkout_branch "$branch" "$resolved_ref"
  fi

  if _load_git_reset_remote; then
    git-reset-remote --ref "$resolved_ref" --no-fetch --clean --yes
    return 0
  fi

  git reset --hard "$resolved_ref"
  git clean -fd
}

_reset_repo_to_ref "$repo_dir" "$ref"
EOF
}

# _codex_workspace_container_list_git_repos <container> [root] [depth]
# List git repo dirs under <root> inside a workspace container.
_codex_workspace_container_list_git_repos() {
  emulate -L zsh
  setopt pipe_fail

  local container="${1:?missing container}"
  local root="${2:-/work}"
  local depth="${3:-2}"

  docker exec -i -u codex "$container" zsh -s -- "$root" "$depth" <<'EOF'
set -euo pipefail

root="${1:?missing root}"
depth="${2:?missing depth}"

if [[ "$depth" != <-> || "$depth" -le 0 ]]; then
  print -u2 -r -- "error: --depth must be a positive integer (got: $depth)"
  exit 2
fi

if [[ ! -d "$root" ]]; then
  print -u2 -r -- "error: root not found: $root"
  exit 1
fi

	typeset -i git_depth=$((depth + 1))
	typeset -a repos=()

	while IFS= read -r -d '' git_entry; do
	  repos+=("${git_entry:h}")
	done < <(find -L "$root" -maxdepth "$git_depth" -mindepth 2 \( -type d -o -type f \) -name .git -print0 2>/dev/null)

print -rl -- ${(ou)repos}
EOF
}

# codex-workspace-reset <subcommand> [args...]
# Reset helpers under the `codex-workspace reset ...` namespace.
codex-workspace-reset() {
  emulate -L zsh
  setopt pipe_fail

  local subcmd="${1:-}"
  case "$subcmd" in
    ""|-h|--help)
      cat <<'EOF'
usage:
  codex-workspace reset repo <name|container> <repo_dir> [--ref <remote/branch>] [--yes]
  codex-workspace reset work-repos <name|container> [--root <dir>] [--depth <N>] [--ref <remote/branch>] [--yes]
  codex-workspace reset opt-repos <name|container> [--yes]
  codex-workspace reset private-repo <name|container> [--ref <remote/branch>] [--yes]

subcommands:
  repo         Reset a single repo inside the container
  work-repos   Reset all git repos under a root dir (default: /work)
  opt-repos    Refresh /opt/codex-kit + /opt/zsh-kit inside the container
  private-repo Reset ~/.private inside the container
EOF
      return 0
      ;;
    repo)
      shift 1 2>/dev/null || true
      codex-workspace-reset-repo "$@"
      return $?
      ;;
    work-repos)
      shift 1 2>/dev/null || true
      codex-workspace-reset-work-repos "$@"
      return $?
      ;;
    opt-repos)
      shift 1 2>/dev/null || true
      codex-workspace-refresh-opt-repos "$@"
      return $?
      ;;
    private-repo)
      shift 1 2>/dev/null || true
      codex-workspace-reset-private-repo "$@"
      return $?
      ;;
    *)
      print -u2 -r -- "error: unknown reset subcommand: $subcmd"
      print -u2 -r -- "hint: codex-workspace reset --help"
      return 2
      ;;
  esac
}

# codex-workspace-reset-repo <container> <repo_dir> [--ref <remote/branch>] [--yes]
# Reset a single repo inside a workspace container.
codex-workspace-reset-repo() {
  emulate -L zsh
  setopt pipe_fail

  local name="${1:-}"
  local repo_dir="${2:-}"
  if [[ -z "$name" || "$name" == "-h" || "$name" == "--help" ]]; then
    cat <<'EOF'
usage: codex-workspace-reset-repo <name|container> <repo_dir> [--ref <remote/branch>] [--yes]

Reset a repo inside a workspace container to a remote-tracking branch.
Defaults:
  --ref origin/main
Notes:
  - Forces checkout to the target branch before resetting.
  - Discards tracked changes (hard reset) and removes untracked files/dirs (git clean -fd).
EOF
    return 0
  fi

  if [[ -z "$repo_dir" ]]; then
    print -u2 -r -- "error: missing required args"
    print -u2 -r -- "hint: codex-workspace-reset-repo <container> <repo_dir> [--ref origin/main]"
    return 2
  fi

  shift 2 2>/dev/null || true

  local ref="origin/main"
  local want_yes=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ref)
        ref="${2:-}"
        shift 2 || break
        ;;
      -y|--yes)
        want_yes=1
        shift
        ;;
      -h|--help)
        cat <<'EOF'
usage: codex-workspace-reset-repo <name|container> <repo_dir> [--ref <remote/branch>] [--yes]

Reset a repo inside a workspace container to a remote-tracking branch.
Defaults:
  --ref origin/main
Notes:
  - Forces checkout to the target branch before resetting.
  - Discards tracked changes (hard reset) and removes untracked files/dirs (git clean -fd).
EOF
        return 0
        ;;
      *)
        print -u2 -r -- "error: unknown arg: $1"
        return 2
        ;;
    esac
  done

  if [[ -z "$name" || -z "$repo_dir" ]]; then
    print -u2 -r -- "error: missing required args"
    print -u2 -r -- "hint: codex-workspace-reset-repo <container> <repo_dir> [--ref origin/main]"
    return 2
  fi

  _codex_workspace_require_docker || return $?
  local container=''
  if (( $+functions[_codex_workspace_normalize_container_name] )); then
    container="$(_codex_workspace_normalize_container_name "$name")" || return 1
  else
    local prefix="${CODEX_WORKSPACE_PREFIX:-codex-ws}"
    if [[ "$name" == "${prefix}-"* ]]; then
      container="$name"
    else
      container="${prefix}-${name}"
    fi
  fi
  _codex_workspace_require_container "$container" || return $?

  if (( !want_yes )); then
    print -r -- "This will reset a repo inside container: $container"
    _codex_workspace_print_folders "$repo_dir"
    print -r --
    print -r -- "Actions:"
    print -r -- "  - Force checkout to target branch (default: main)"
    print -r -- "  - git reset --hard <remote/branch> (DISCARDS tracked changes)"
    print -r -- "  - git clean -fd (REMOVES untracked files/dirs)"
    _codex_workspace_confirm_or_abort "❓ Proceed? [y/N] " || return 1
  fi

  _codex_workspace_container_reset_repo "$container" "$repo_dir" "$ref"
}

# codex-workspace-reset-private-repo <container> [--ref <remote/branch>] [--yes]
# Reset ~/.private inside a workspace container.
codex-workspace-reset-private-repo() {
  emulate -L zsh
  setopt pipe_fail

  local name="${1:-}"
  if [[ -z "$name" || "$name" == "-h" || "$name" == "--help" ]]; then
    cat <<'EOF'
usage: codex-workspace-reset-private-repo <name|container> [--ref <remote/branch>] [--yes]

Reset ~/.private inside a workspace container to a remote-tracking branch.
Defaults:
  --ref origin/main
Notes:
  - If ~/.private is missing (or not a git repo), this is a no-op.
  - Discards tracked changes (hard reset) and removes untracked files/dirs (git clean -fd).
EOF
    return 0
  fi

  shift 1 2>/dev/null || true

  local ref="origin/main"
  local want_yes=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ref)
        ref="${2:-}"
        shift 2 || break
        ;;
      -y|--yes)
        want_yes=1
        shift
        ;;
      -h|--help)
        cat <<'EOF'
usage: codex-workspace-reset-private-repo <name|container> [--ref <remote/branch>] [--yes]

Reset ~/.private inside a workspace container to a remote-tracking branch.
Defaults:
  --ref origin/main
Notes:
  - If ~/.private is missing (or not a git repo), this is a no-op.
  - Discards tracked changes (hard reset) and removes untracked files/dirs (git clean -fd).
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
    print -u2 -r -- "error: missing container"
    print -u2 -r -- "hint: codex-workspace-reset-private-repo <container> [--ref origin/main]"
    return 2
  fi

  _codex_workspace_require_docker || return $?
  local container=''
  if (( $+functions[_codex_workspace_normalize_container_name] )); then
    container="$(_codex_workspace_normalize_container_name "$name")" || return 1
  else
    local prefix="${CODEX_WORKSPACE_PREFIX:-codex-ws}"
    if [[ "$name" == "${prefix}-"* ]]; then
      container="$name"
    else
      container="${prefix}-${name}"
    fi
  fi
  _codex_workspace_require_container "$container" || return $?

  local repo_dir="/home/codex/.private"

  if ! docker exec -u codex "$container" bash -lc 'test -d "$HOME/.private/.git"' >/dev/null 2>&1; then
    print -u2 -r -- "warn: ~/.private not found (or not a git repo) in container: $container"
    print -u2 -r -- "hint: seed it with: CODEX_WORKSPACE_PRIVATE_REPO=OWNER/REPO codex-workspace create ..."
    return 0
  fi

  if (( !want_yes )); then
    print -r -- "This will reset ~/.private inside container: $container"
    _codex_workspace_print_folders "$repo_dir"
    print -r --
    print -r -- "Actions:"
    print -r -- "  - Force checkout to target branch (default: main)"
    print -r -- "  - git reset --hard <remote/branch> (DISCARDS tracked changes)"
    print -r -- "  - git clean -fd (REMOVES untracked files/dirs)"
    _codex_workspace_confirm_or_abort "❓ Proceed? [y/N] " || return 1
  fi

  _codex_workspace_container_reset_repo "$container" "$repo_dir" "$ref"
}

# codex-workspace-reset-work-repos <container> [--root <dir>] [--depth <N>] [--ref <remote/branch>] [--yes]
# Reset all git repos under a root directory inside a workspace container.
codex-workspace-reset-work-repos() {
  emulate -L zsh
  setopt pipe_fail

  local name="${1:-}"
  if [[ -z "$name" || "$name" == "-h" || "$name" == "--help" ]]; then
    cat <<'EOF'
usage: codex-workspace-reset-work-repos <name|container> [--root <dir>] [--depth <N>] [--ref <remote/branch>] [--yes]

	Reset all git repos under a root directory inside a workspace container.
	Defaults:
	  --root /work
	  --depth 3          # repo roots up to: /work/*/*/*
	  --ref origin/main
EOF
    return 0
  fi

  shift 1 2>/dev/null || true

  local root="/work"
  local depth="3"
  local ref="origin/main"
  local want_yes=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --root)
        root="${2:-}"
        shift 2 || break
        ;;
      --depth)
        depth="${2:-}"
        shift 2 || break
        ;;
      --ref)
        ref="${2:-}"
        shift 2 || break
        ;;
      -y|--yes)
        want_yes=1
        shift
        ;;
      -h|--help)
        cat <<'EOF'
usage: codex-workspace-reset-work-repos <name|container> [--root <dir>] [--depth <N>] [--ref <remote/branch>] [--yes]

	Reset all git repos under a root directory inside a workspace container.
	Defaults:
	  --root /work
	  --depth 3          # repo roots up to: /work/*/*/*
	  --ref origin/main
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
    print -u2 -r -- "error: missing container"
    print -u2 -r -- "hint: codex-workspace-reset-work-repos <container> [--depth 3]"
    return 2
  fi

  _codex_workspace_require_docker || return $?
  local container=''
  if (( $+functions[_codex_workspace_normalize_container_name] )); then
    container="$(_codex_workspace_normalize_container_name "$name")" || return 1
  else
    local prefix="${CODEX_WORKSPACE_PREFIX:-codex-ws}"
    if [[ "$name" == "${prefix}-"* ]]; then
      container="$name"
    else
      container="${prefix}-${name}"
    fi
  fi
  _codex_workspace_require_container "$container" || return $?

  local repos_out=''
  repos_out="$(_codex_workspace_container_list_git_repos "$container" "$root" "$depth")" || return $?

  if [[ -z "$repos_out" ]]; then
    print -u2 -r -- "warn: no git repos found under $root (depth=$depth) in $container"
    return 0
  fi

  local -a repo_dirs
  repo_dirs=("${(@f)repos_out}")

  if (( !want_yes )); then
    print -r -- "This will reset ${#repo_dirs} repos inside container: $container"
    _codex_workspace_print_folders "${repo_dirs[@]}"
    print -r --
    print -r -- "Actions:"
    print -r -- "  - Force checkout to target branch (default: main)"
    print -r -- "  - git reset --hard <remote/branch> (DISCARDS tracked changes)"
    print -r -- "  - git clean -fd (REMOVES untracked files/dirs)"
    _codex_workspace_confirm_or_abort "❓ Proceed? [y/N] " || return 1
  fi

  local reset_script=''
  reset_script="$(cat <<'EOF'
set -euo pipefail

ref="${1:-origin/main}"

# _load_git_reset_remote
# Load git-reset-remote when available (preferred: function, fallback: zsh-kit file).
_load_git_reset_remote() {
  if typeset -f git-reset-remote >/dev/null 2>&1; then
    return 0
  fi
  if [[ -f /opt/zsh-kit/scripts/git/tools/git-reset.zsh ]]; then
    source /opt/zsh-kit/scripts/git/tools/git-reset.zsh
    return 0
  fi
  return 1
}

# _resolve_target_ref <remote/branch>
# Resolve and validate a remote-tracking ref (fallbacks: remote/HEAD, then remote/master).
_resolve_target_ref() {
  local ref="$1"
  local remote="${ref%%/*}"
  local branch="${ref#*/}"

  if [[ "$remote" == "$ref" || -z "$remote" || -z "$branch" ]]; then
    print -u2 -r -- "error: invalid ref (expected remote/branch): $ref"
    return 2
  fi

  git fetch --prune -- "$remote" >/dev/null 2>&1 || git fetch --prune -- "$remote"

  if git show-ref --verify --quiet "refs/remotes/$remote/$branch"; then
    print -r -- "$remote/$branch"
    return 0
  fi

  local default_ref=''
  default_ref="$(git symbolic-ref -q --short "refs/remotes/$remote/HEAD" 2>/dev/null || true)"
  local default_branch="${default_ref#${remote}/}"
  if [[ -n "$default_branch" && "$default_branch" != "$default_ref" ]]; then
    if git show-ref --verify --quiet "refs/remotes/$remote/$default_branch"; then
      print -u2 -r -- "warn: $remote/$branch not found; using $remote/$default_branch (from $remote/HEAD)"
      print -r -- "$remote/$default_branch"
      return 0
    fi
  fi

  if git show-ref --verify --quiet "refs/remotes/$remote/master"; then
    print -u2 -r -- "warn: $remote/$branch not found; using $remote/master"
    print -r -- "$remote/master"
    return 0
  fi

  print -u2 -r -- "error: remote branch not found: $remote/$branch"
  return 1
}

# _force_checkout_branch <branch> [start_point]
# Force checkout a branch, cleaning untracked files if needed.
_force_checkout_branch() {
  local branch="$1"
  local start_point="${2:-}"

  if [[ -n "$start_point" ]]; then
    git checkout --force -B "$branch" "$start_point" >/dev/null 2>&1 && return 0
    git clean -fd >/dev/null 2>&1 || true
    git checkout --force -B "$branch" "$start_point"
    return $?
  fi

  git checkout --force "$branch" >/dev/null 2>&1 && return 0
  git clean -fd >/dev/null 2>&1 || true
  git checkout --force "$branch"
}

# _reset_repo_to_ref <repo_dir> <remote/branch>
# Reset a repo dir to the resolved remote-tracking ref (hard reset + clean).
_reset_repo_to_ref() {
  local repo_dir="$1"
  local ref="$2"

  if [[ ! -e "$repo_dir/.git" ]]; then
    print -u2 -r -- "warn: missing git repo: $repo_dir"
    return 0
  fi

  cd "$repo_dir"

  local resolved_ref=''
  resolved_ref="$(_resolve_target_ref "$ref")" || return $?

  local branch="${resolved_ref#*/}"

  print -r -- "+ reset $repo_dir -> $resolved_ref"

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    _force_checkout_branch "$branch"
  else
    _force_checkout_branch "$branch" "$resolved_ref"
  fi

  if _load_git_reset_remote; then
    git-reset-remote --ref "$resolved_ref" --no-fetch --clean --yes
    return 0
  fi

  git reset --hard "$resolved_ref"
  git clean -fd
}

typeset -i fail_count=0
while IFS= read -r repo_dir; do
  [[ -n "$repo_dir" ]] || continue
  if ! _reset_repo_to_ref "$repo_dir" "$ref"; then
    fail_count=$((fail_count + 1))
  fi
done

if (( fail_count > 0 )); then
  print -u2 -r -- "error: failed to reset $fail_count repo(s)"
  exit 1
	fi
EOF

)"

  # Feed repo dirs via stdin; pass the reset script via `zsh -c` to avoid stdin conflicts.
  print -r -- "$repos_out" | docker exec -i -u codex "$container" zsh -c "$reset_script" -- "$ref"
}

# codex-workspace-refresh-opt-repos <name|container> [--yes]
# Force-update the image-bundled repos inside a workspace container.
codex-workspace-refresh-opt-repos() {
  emulate -L zsh
  setopt pipe_fail

  local name="${1:-}"
  if [[ -z "$name" || "$name" == "-h" || "$name" == "--help" ]]; then
    cat <<'EOF'
usage: codex-workspace-refresh-opt-repos <name|container> [--yes]

Force-update the image-bundled repos inside a workspace container:
  - /opt/codex-kit
  - /opt/zsh-kit

Notes:
  - Uses `git-reset-remote --yes` when available (fallback: git fetch/reset/clean).
  - Re-wires zsh-kit codex secrets symlink when secrets are mounted.
  - Add --yes to skip the preflight confirmation prompt.
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
usage: codex-workspace-refresh-opt-repos <name|container> [--yes]

Force-update the image-bundled repos inside a workspace container:
  - /opt/codex-kit
  - /opt/zsh-kit

Notes:
  - Uses `git-reset-remote --yes` when available (fallback: git fetch/reset/clean).
  - Re-wires zsh-kit codex secrets symlink when secrets are mounted.
  - Add --yes to skip the preflight confirmation prompt.
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
    print -u2 -r -- "error: missing container"
    print -u2 -r -- "hint: codex-workspace-refresh-opt-repos <container>"
    return 2
  fi

  _codex_workspace_require_docker || return $?

  local container=''
  if (( $+functions[_codex_workspace_normalize_container_name] )); then
    container="$(_codex_workspace_normalize_container_name "$name")" || return 1
  else
    local prefix="${CODEX_WORKSPACE_PREFIX:-codex-ws}"
    if [[ "$name" == "${prefix}-"* ]]; then
      container="$name"
    else
      container="${prefix}-${name}"
    fi
  fi
  _codex_workspace_require_container "$container" || return $?

  local -a repo_dirs=(/opt/codex-kit /opt/zsh-kit)
  if (( !want_yes )); then
    print -r -- "This will reset /opt repos inside container: $container"
    _codex_workspace_print_folders "${repo_dirs[@]}"
    print -r --
    print -r -- "Actions:"
    print -r -- "  - Force checkout to target branch (default: main)"
    print -r -- "  - git reset --hard <remote/branch> (DISCARDS tracked changes)"
    print -r -- "  - git clean -fd (REMOVES untracked files/dirs)"
    _codex_workspace_confirm_or_abort "❓ Proceed? [y/N] " || return 1
  fi

  print -r -- "+ refresh /opt repos in $container"
  docker exec -i -u codex "$container" zsh -s -- <<'EOF'
set -euo pipefail

if command -v gh >/dev/null 2>&1; then
  gh config set git_protocol https -h github.com 2>/dev/null || gh config set git_protocol https 2>/dev/null || true
fi

# _restore_zsh_kit_codex_secrets_mount <dst>
# If secrets are mounted outside the default, restore the zsh-kit codex secrets symlink.
_restore_zsh_kit_codex_secrets_mount() {
  local src="/opt/zsh-kit/scripts/_features/codex/secrets"
  local dst="${1:-}"
  [[ -n "$dst" ]] || return 0
  [[ "$dst" != "$src" ]] || return 0
  [[ -d "$dst" ]] || return 0

  if [[ ! -f "$dst/_codex-secret.zsh" ]]; then
    local -a json_files=("$dst"/*.json(N))
    (( ${#json_files} > 0 )) || return 0
  fi

  if [[ -L "$src" && "$(readlink "$src" 2>/dev/null || true)" == "$dst" ]]; then
    return 0
  fi

  rm -rf "$src"
  ln -s "$dst" "$src"
}

# _load_git_reset_remote
# Load git-reset-remote when available (preferred: function, fallback: zsh-kit file).
_load_git_reset_remote() {
  if typeset -f git-reset-remote >/dev/null 2>&1; then
    return 0
  fi
  if [[ -f /opt/zsh-kit/scripts/git/tools/git-reset.zsh ]]; then
    source /opt/zsh-kit/scripts/git/tools/git-reset.zsh
    return 0
  fi
  return 1
}

# _resolve_target_ref <remote/branch>
# Resolve and validate a remote-tracking ref (fallbacks: remote/HEAD, then remote/master).
_resolve_target_ref() {
  local ref="$1"
  local remote="${ref%%/*}"
  local branch="${ref#*/}"

  if [[ "$remote" == "$ref" || -z "$remote" || -z "$branch" ]]; then
    print -u2 -r -- "error: invalid ref (expected remote/branch): $ref"
    return 2
  fi

  git fetch --prune -- "$remote" >/dev/null 2>&1 || git fetch --prune -- "$remote"

  if git show-ref --verify --quiet "refs/remotes/$remote/$branch"; then
    print -r -- "$remote/$branch"
    return 0
  fi

  local default_ref=''
  default_ref="$(git symbolic-ref -q --short "refs/remotes/$remote/HEAD" 2>/dev/null || true)"
  local default_branch="${default_ref#${remote}/}"
  if [[ -n "$default_branch" && "$default_branch" != "$default_ref" ]]; then
    if git show-ref --verify --quiet "refs/remotes/$remote/$default_branch"; then
      print -u2 -r -- "warn: $remote/$branch not found; using $remote/$default_branch (from $remote/HEAD)"
      print -r -- "$remote/$default_branch"
      return 0
    fi
  fi

  if git show-ref --verify --quiet "refs/remotes/$remote/master"; then
    print -u2 -r -- "warn: $remote/$branch not found; using $remote/master"
    print -r -- "$remote/master"
    return 0
  fi

  print -u2 -r -- "error: remote branch not found: $remote/$branch"
  return 1
}

# _force_checkout_branch <branch> [start_point]
# Force checkout a branch, cleaning untracked files if needed.
_force_checkout_branch() {
  local branch="$1"
  local start_point="${2:-}"

  if [[ -n "$start_point" ]]; then
    git checkout --force -B "$branch" "$start_point" >/dev/null 2>&1 && return 0
    git clean -fd >/dev/null 2>&1 || true
    git checkout --force -B "$branch" "$start_point"
    return $?
  fi

  git checkout --force "$branch" >/dev/null 2>&1 && return 0
  git clean -fd >/dev/null 2>&1 || true
  git checkout --force "$branch"
}

# _reset_repo_to_ref <repo_dir> <remote/branch>
# Reset a repo dir to the resolved remote-tracking ref (hard reset + clean).
_reset_repo_to_ref() {
  local repo_dir="$1"
  local ref="$2"

  if [[ ! -d "$repo_dir" || ! -e "$repo_dir/.git" ]]; then
    print -u2 -r -- "warn: missing git repo: $repo_dir"
    return 0
  fi

  cd "$repo_dir"

  local resolved_ref=''
  resolved_ref="$(_resolve_target_ref "$ref")" || return $?

  local branch="${resolved_ref#*/}"

  print -r -- "+ reset $repo_dir -> $resolved_ref"

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    _force_checkout_branch "$branch"
  else
    _force_checkout_branch "$branch" "$resolved_ref"
  fi

  if _load_git_reset_remote; then
    git-reset-remote --ref "$resolved_ref" --no-fetch --clean --yes
    return 0
  fi

  print -u2 -r -- "warn: git-reset-remote not found; falling back to git reset/clean ($repo_dir)"
  git reset --hard "$resolved_ref"
  git clean -fd
}

# _detect_codex_secrets_mount
# Detect the codex secrets mount path in the container (symlink or common defaults).
_detect_codex_secrets_mount() {
  local src="/opt/zsh-kit/scripts/_features/codex/secrets"
  local dst=''

  if [[ -L "$src" ]]; then
    dst="$(readlink "$src" 2>/dev/null || true)"
  fi

  if [[ -z "$dst" && -n "${CODEX_SECRET_DIR-}" ]]; then
    dst="${CODEX_SECRET_DIR-}"
  fi

  if [[ -z "$dst" && -d "$HOME/codex_secrets" ]]; then
    if [[ -f "$HOME/codex_secrets/_codex-secret.zsh" ]]; then
      dst="$HOME/codex_secrets"
    else
      local -a json_files=("$HOME/codex_secrets"/*.json(N))
      (( ${#json_files} > 0 )) && dst="$HOME/codex_secrets"
    fi
  fi

  if [[ -z "$dst" && -d /home/codex/codex_secrets ]]; then
    if [[ -f /home/codex/codex_secrets/_codex-secret.zsh ]]; then
      dst="/home/codex/codex_secrets"
    else
      local -a json_files=(/home/codex/codex_secrets/*.json(N))
      (( ${#json_files} > 0 )) && dst="/home/codex/codex_secrets"
    fi
  fi

  [[ -n "$dst" ]] || return 1
  print -r -- "$dst"
}

codex_secrets_mount="$(_detect_codex_secrets_mount 2>/dev/null || true)"

_reset_repo_to_ref /opt/codex-kit origin/main
_reset_repo_to_ref /opt/zsh-kit origin/main
_restore_zsh_kit_codex_secrets_mount "$codex_secrets_mount"
EOF
}
