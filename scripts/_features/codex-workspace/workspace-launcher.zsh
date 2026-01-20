# Host helper to start a Codex workspace container (Dev Containers mode) (feature: codex-workspace).
#
# Usage:
#   codex-workspace
#   codex-workspace create [--private-repo <owner/repo|URL>] [<owner/repo|URL>...]
#   codex-workspace auth codex [--profile <name>] [--container <name|container>]
#   codex-workspace auth github [--host <host>] [--container <name|container>]
#   codex-workspace auth gpg [--key <keyid|fingerprint>] [--container <name|container>]
#
# Example:
#   codex-workspace create OWNER/REPO
#   codex-workspace auth github
#   codex-workspace auth codex --profile work
#
# Env:
# - CODEX_WORKSPACE_PRIVATE_REPO: optional; clone/pull this repo into ~/.private inside the container.

if command -v safe_unalias >/dev/null; then
  safe_unalias \
    cw
fi

# cw
# Alias of `codex-workspace`.
# Usage: cw <subcommand> [args...]
alias cw='codex-workspace'

# _codex_workspace_tunnel_name_hash4 <input>
# Print a 4-char hash used for VS Code tunnel name shortening.
_codex_workspace_tunnel_name_hash4() {
  emulate -L zsh
  setopt pipe_fail

  local input="${1:-}"
  [[ -n "$input" ]] || return 1

  local hash4=''
  if command -v shasum >/dev/null 2>&1; then
    hash4="$(print -n -r -- "$input" | shasum -a 1 2>/dev/null | awk '{print $1}' | cut -c1-4)"
  elif command -v sha1sum >/dev/null 2>&1; then
    hash4="$(print -n -r -- "$input" | sha1sum 2>/dev/null | awk '{print $1}' | cut -c1-4)"
  elif command -v openssl >/dev/null 2>&1; then
    hash4="$(print -n -r -- "$input" | openssl sha1 2>/dev/null | awk '{print $2}' | cut -c1-4)"
  elif command -v python3 >/dev/null 2>&1; then
    hash4="$(python3 -c 'import hashlib,sys; print(hashlib.sha1(sys.argv[1].encode()).hexdigest()[:4])' "$input" 2>/dev/null || true)"
  fi

  [[ -n "$hash4" ]] || hash4="0000"
  print -r -- "$hash4"
  return 0
}

# _codex_workspace_tunnel_name_sanitize <name>
# Normalize a tunnel name candidate (lowercase, alnum + '-') for VS Code.
_codex_workspace_tunnel_name_sanitize() {
  emulate -L zsh

  local name="${1:-}"
  name="${name:l}"
  name="${name//[^a-z0-9-]/-}"
  while [[ "$name" == *--* ]]; do
    name="${name//--/-}"
  done
  name="${name##-}"
  name="${name%%-}"
  [[ -n "$name" ]] || name="ws"

  print -r -- "$name"
  return 0
}

# _codex_workspace_tunnel_default_name <container>
# Derive a default VS Code tunnel name (<= 20 chars) from the workspace container name.
_codex_workspace_tunnel_default_name() {
  emulate -L zsh
  setopt pipe_fail

  local container="${1:-}"
  [[ -n "$container" ]] || return 1

  local prefix="${CODEX_WORKSPACE_PREFIX:-codex-ws}"
  local base="${container#${prefix}-}"

  # Common pattern: <owner>-<repo>-YYYYMMDD-HHMMSS
  local candidate="$base"
  if [[ "$candidate" == *-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9] ]]; then
    candidate="${candidate%-[0-9][0-9][0-9][0-9][0-9][0-9]}"
    candidate="${candidate%-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]}"
  fi

  candidate="$(_codex_workspace_tunnel_name_sanitize "$candidate")"

  local -i max_len=20
  if (( ${#candidate} <= max_len )); then
    print -r -- "$candidate"
    return 0
  fi

  local hash4="$(_codex_workspace_tunnel_name_hash4 "$container")"
  local -i prefix_len=$(( max_len - 5 )) # "<prefix>-<hash4>"
  local short_prefix="${candidate[1,prefix_len]}"
  while [[ "$short_prefix" == *- ]]; do
    short_prefix="${short_prefix%-}"
  done
  [[ -n "$short_prefix" ]] || short_prefix="ws"
  short_prefix="$(_codex_workspace_tunnel_name_sanitize "$short_prefix")"

  local shortened="${short_prefix}-${hash4}"
  print -r -- "${shortened[1,max_len]}"
  return 0
}

# _codex_workspace_repo_default_from_cwd
# Print a best-effort repo URL from the current git worktree (origin preferred).
_codex_workspace_repo_default_from_cwd() {
  emulate -L zsh
  setopt pipe_fail

  command -v git >/dev/null 2>&1 || return 1
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1

  local url=''
  url="$(git remote get-url origin 2>/dev/null || true)"
  if [[ -n "$url" ]]; then
    print -r -- "$url"
    return 0
  fi

  local -a remotes=()
  remotes=(${(f)"$(git remote 2>/dev/null || true)"})
  local remote=''
  for remote in "${remotes[@]}"; do
    url="$(git remote get-url "$remote" 2>/dev/null || true)"
    [[ -n "$url" ]] || continue
    print -r -- "$url"
    return 0
  done

  return 1
}

# _codex_workspace_usage
# Print CLI usage/help for `codex-workspace`.
_codex_workspace_usage() {
  emulate -L zsh

  cat <<'EOF'
usage:
  codex-workspace
  codex-workspace auth <provider> [options] [<name|container>]
  codex-workspace ls
  codex-workspace create [--no-extras] [--codex-profile <name>] [--private-repo <owner/repo|URL>] [--gpg|--no-gpg] [--gpg-key <keyid|fingerprint>] [<owner/repo|URL>...]
  codex-workspace create --no-work-repos --name <name> [--no-extras] [--codex-profile <name>] [--private-repo <owner/repo|URL>]
  codex-workspace exec [--root] [--user <user>] <name|container> [--] [cmd...]
  codex-workspace rm <name|container> [--yes]
  codex-workspace rm --all [--yes]
  codex-workspace reset repo <name|container> <repo_dir> [--ref <remote/branch>] [--yes]
  codex-workspace reset work-repos <name|container> [--root <dir>] [--depth <N>] [--ref <remote/branch>] [--yes]
  codex-workspace reset opt-repos <name|container> [--yes]
  codex-workspace reset private-repo <name|container> [--ref <remote/branch>] [--yes]
  codex-workspace tunnel <container> [--name <tunnel_name>] [--detach]

example:
  codex-workspace create OWNER/REPO
  codex-workspace create OWNER/REPO OTHER/REPO  # clones in order
  codex-workspace create                        # uses current git remote (origin)
  codex-workspace create --no-extras OWNER/REPO  # skip cloning ~/.private and extra repos
  codex-workspace create --codex-profile work OWNER/REPO
  codex-workspace create --gpg OWNER/REPO        # import host gpg signing key into container
  codex-workspace create --no-work-repos --name ws-foo
  codex-workspace create --no-work-repos --name ws-foo --private-repo OWNER/PRIVATE_REPO
  codex-workspace create --private-repo OWNER/PRIVATE_REPO OWNER/REPO
  CODEX_WORKSPACE_PRIVATE_REPO=OWNER/PRIVATE_REPO codex-workspace create OWNER/REPO
  codex-workspace auth github
  codex-workspace auth codex --profile work
  codex-workspace auth gpg --key <fingerprint>
  codex-workspace ls
  codex-workspace exec ws-foo
  codex-workspace reset work-repos ws-foo --yes
  codex-workspace reset opt-repos ws-foo --yes
  codex-workspace reset private-repo ws-foo --yes
  codex-workspace rm --all

notes:
  - `codex-workspace` prints help; use `codex-workspace create ...` to start a workspace.
  - Repo args are optional when inside a git repo (defaults to `git remote get-url origin`),
    unless `--no-work-repos` is used.
  - Use `--no-extras` to disable cloning `~/.private` and additional repos under `/work`.
  - Use `--no-work-repos` to create a workspace without cloning any repos into `/work`
    (including the default-from-CWD `origin`); requires `--name` and rejects repo args.
  - If the codex-kit launcher script is missing, this function auto-downloads it from GitHub.
    - Disable auto-download with: CODEX_WORKSPACE_LAUNCHER_AUTO_DOWNLOAD=false
    - Override the source with: CODEX_WORKSPACE_LAUNCHER_URL=<url>
    - Override the install path with: CODEX_WORKSPACE_LAUNCHER_AUTO_PATH=<path>
    - Or set an explicit launcher with: CODEX_WORKSPACE_LAUNCHER=<path>
  - Auth is automatic by default:
    - If `gh` is logged in (keyring), this function prefers that token (works better across orgs).
    - Otherwise it falls back to host GH_TOKEN/GITHUB_TOKEN.
    - Override with: CODEX_WORKSPACE_AUTH=env|gh|auto|none
  - GPG signing is opt-in (imports host secret key into container):
    - Enable on create: `--gpg` (optionally `--gpg-key ...`)
    - Or re-apply later: `codex-workspace auth gpg`
    - Configure defaults via: CODEX_WORKSPACE_GPG=import|none and CODEX_WORKSPACE_GPG_KEY=<key>
  - Codex profiles can be set on create with CODEX_WORKSPACE_CODEX_PROFILE or --codex-profile <name>.
  - Use `codex-workspace auth codex|github|gpg` to re-apply auth to an existing workspace.
  - If org SSO blocks access, run: `env -u GH_TOKEN -u GITHUB_TOKEN gh auth refresh -h github.com -s repo -s read:org`
  - VS Code: if you see "cannot find workspace /work/..." you likely attached from an existing window;
    open a new window, or run the printed `code --new-window --folder-uri ...` command.
  - To auto-open VS Code after launch: `CODEX_WORKSPACE_OPEN_VSCODE_ENABLED=true codex-workspace create OWNER/REPO`
  - On each workspace creation, it refreshes `/opt/codex-kit` + `/opt/zsh-kit` in the container.
  - This function snapshots host ~/.config into the container (copy, not bind-mount),
    excluding ~/.config/codex-kit and ~/.config/zsh to avoid conflicts.
  - Host codex secrets (~/.config/codex_secrets) are bind-mounted read-write to ~/codex_secrets.
  - Optional: to seed container ~/.private from a dedicated repo, set:
      - CODEX_WORKSPACE_PRIVATE_REPO=OWNER/REPO (or URL)
      - or pass: --private-repo OWNER/REPO (or URL)
  - VS Code: Cmd+Shift+P -> "Dev Containers: Attach to Running Container..."
EOF

  return 0
}

# _codex_workspace_default_gpg_signing_key
# Return a best-effort host signing key to import (prefers explicit env var).
_codex_workspace_default_gpg_signing_key() {
  emulate -L zsh
  setopt pipe_fail

  local key="${CODEX_WORKSPACE_GPG_KEY-}"
  key="${key%%[[:space:]]#}"
  if [[ -n "$key" ]]; then
    print -r -- "$key"
    return 0
  fi

  if command -v git >/dev/null 2>&1; then
    key="$(git config --global --get user.signingkey 2>/dev/null || true)"
    key="${key%%[[:space:]]#}"
    if [[ -n "$key" ]]; then
      print -r -- "$key"
      return 0
    fi
  fi

  return 1
}

# _codex_workspace_auth_gpg <container> [key]
# Import the host GPG secret key into the workspace container (so `git commit -S` works).
_codex_workspace_auth_gpg() {
  emulate -L zsh
  setopt pipe_fail

  local container="${1:?missing container}"
  local key="${2-}"

  if [[ -z "${key//[[:space:]]/}" ]]; then
    key="$(_codex_workspace_default_gpg_signing_key 2>/dev/null || true)"
  fi

  if [[ -z "${key//[[:space:]]/}" ]]; then
    print -u2 -r -- "error: missing gpg signing key"
    print -u2 -r -- "hint: pass --key <fingerprint> or set CODEX_WORKSPACE_GPG_KEY"
    print -u2 -r -- "hint: or set: git config --global user.signingkey <keyid>"
    return 1
  fi

  if ! command -v gpg >/dev/null 2>&1; then
    print -u2 -r -- "error: gpg not found on host (required to export secret key)"
    print -u2 -r -- "hint: install gnupg (brew install gnupg)"
    return 1
  fi

  _codex_workspace_ensure_container_running "$container" || return $?

  print -r -- "auth: gpg -> $container (key=$key)"

  # Export on host, import into container. Avoid writing key material to disk.
  if ! gpg --batch --armor --export-secret-keys -- "$key" \
    | docker exec -i -u codex "$container" bash -c '
      set -euo pipefail
      if ! command -v gpg >/dev/null 2>&1; then
        echo "error: gpg not installed in container" >&2
        exit 127
      fi
      umask 077
      mkdir -p "$HOME/.gnupg"
      chmod 700 "$HOME/.gnupg" 2>/dev/null || true
      gpg --batch --import >/dev/null 2>&1
    '; then
    print -u2 -r -- "error: failed to import gpg secret key into $container"
    print -u2 -r -- "hint: verify the host key exists: gpg --list-secret-keys -- '$key'"
    return 1
  fi

  # Best-effort verification (quiet).
  docker exec -u codex "$container" bash -lc 'gpg --list-secret-keys --keyid-format LONG -- "$1" >/dev/null 2>&1' -- "$key" || {
    print -u2 -r -- "warn: gpg import completed but key lookup failed in container (key=$key)"
  }

  return 0
}

# _codex_workspace_parse_repo_spec <input> [default_host]
# Parse a repo spec (OWNER/REPO or URL) into host/owner/repo and https clone URL.
_codex_workspace_parse_repo_spec() {
  emulate -L zsh
  setopt pipe_fail

  local input="${1:-}"
  local default_host="${2:-github.com}"
  [[ -n "$input" ]] || return 1

  local host="$default_host"
  local owner_repo="$input"

  if [[ "$input" == http://* || "$input" == https://* ]]; then
    local without_scheme="${input#*://}"
    host="${without_scheme%%/*}"
    owner_repo="${without_scheme#*/}"
  elif [[ "$input" == git@*:* ]]; then
    local without_user="${input#git@}"
    host="${without_user%%:*}"
    owner_repo="${input#*:}"
  elif [[ "$input" == ssh://git@*/* ]]; then
    local without_prefix="${input#ssh://git@}"
    host="${without_prefix%%/*}"
    owner_repo="${without_prefix#*/}"
  fi

  owner_repo="${owner_repo%.git}"
  owner_repo="${owner_repo%/}"
  if [[ "$owner_repo" == */*/* ]]; then
    local owner="${owner_repo%%/*}"
    local rest="${owner_repo#*/}"
    local name="${rest%%/*}"
    owner_repo="${owner}/${name}"
  fi
  [[ "$owner_repo" == */* ]] || return 1

  local owner="${owner_repo%%/*}"
  local repo="${owner_repo##*/}"
  local clone_url="https://${host}/${owner}/${repo}.git"

  reply=("$host" "$owner" "$repo" "$owner_repo" "$clone_url")
  return 0
}

# _codex_workspace_launcher_default_path
# Return the default codex-kit launcher path on the host.
_codex_workspace_launcher_default_path() {
  emulate -L zsh

  local primary="$HOME/.codex/docker/codex-env/bin/codex-workspace"
  if [[ -x "$primary" ]]; then
    print -r -- "$primary"
    return 0
  fi

  print -r -- "$HOME/.config/codex-kit/docker/codex-env/bin/codex-workspace"
  return 0
}

# _codex_workspace_launcher_auto_path
# Return the auto-install path for the launcher under XDG cache.
_codex_workspace_launcher_auto_path() {
  emulate -L zsh

  local cache_root="${XDG_CACHE_HOME:-$HOME/.cache}"
  cache_root="${cache_root%/}"
  print -r -- "$cache_root/codex-workspace/launcher/codex-workspace"
  return 0
}

# _codex_workspace_launcher_normalize_url <url>
# Normalize GitHub "blob" URLs to raw URLs for direct downloads.
_codex_workspace_launcher_normalize_url() {
  emulate -L zsh

  local url="${1:-}"
  [[ -n "$url" ]] || return 1

  # Convert GitHub "blob" URLs to raw URLs for direct downloads.
  if [[ "$url" == https://github.com/*/*/blob/* ]]; then
    local without_prefix="${url#https://github.com/}"
    local owner="${without_prefix%%/*}"
    local rest="${without_prefix#*/}"
    local repo="${rest%%/*}"
    rest="${rest#*/}"
    rest="${rest#blob/}"
    local ref="${rest%%/*}"
    local path="${rest#*/}"
    url="https://raw.githubusercontent.com/${owner}/${repo}/${ref}/${path}"
  fi

  print -r -- "$url"
  return 0
}

# _codex_workspace_ensure_launcher <launcher> <explicit>
# Return an executable launcher path; auto-download when missing and not explicit.
_codex_workspace_ensure_launcher() {
  emulate -L zsh
  setopt pipe_fail

  local launcher="${1:-}"
  local -i explicit="${2:-0}"

  [[ -n "$launcher" ]] || return 1

  if [[ -x "$launcher" ]]; then
    print -r -- "$launcher"
    return 0
  fi

  if (( explicit )); then
    print -u2 -r -- "error: launcher not found or not executable: $launcher"
    return 1
  fi

  local auto_download="${CODEX_WORKSPACE_LAUNCHER_AUTO_DOWNLOAD:-true}"
  case "$auto_download" in
    true|"")
      ;;
    false)
      print -u2 -r -- "error: launcher not found: $launcher"
      print -u2 -r -- "hint: auto-download disabled (set CODEX_WORKSPACE_LAUNCHER_AUTO_DOWNLOAD=true to enable)"
      return 1
      ;;
    *)
      print -u2 -r -- "error: CODEX_WORKSPACE_LAUNCHER_AUTO_DOWNLOAD must be true or false (got: $auto_download)"
      return 1
      ;;
  esac

  local auto_path="${CODEX_WORKSPACE_LAUNCHER_AUTO_PATH:-$(_codex_workspace_launcher_auto_path)}"
  if [[ -x "$auto_path" ]]; then
    print -r -- "$auto_path"
    return 0
  fi

  local url_default="https://raw.githubusercontent.com/graysurf/codex-kit/main/docker/codex-env/bin/codex-workspace"
  local url="${CODEX_WORKSPACE_LAUNCHER_URL:-$url_default}"
  url="$(_codex_workspace_launcher_normalize_url "$url" 2>/dev/null || print -r -- "$url")"
  if [[ "$url" != https://* ]]; then
    print -u2 -r -- "error: launcher download URL must be https:// (got: $url)"
    return 1
  fi

  local auto_dir="${auto_path%/*}"
  command mkdir -p -- "$auto_dir" 2>/dev/null || {
    print -u2 -r -- "error: failed to create launcher dir: $auto_dir"
    return 1
  }

  local tmp=''
  tmp="$(mktemp "${TMPDIR:-/tmp}/codex-workspace-launcher.XXXXXX" 2>/dev/null || true)"
  if [[ -z "$tmp" ]]; then
    tmp="$(mktemp -t codex-workspace-launcher.XXXXXX 2>/dev/null || true)"
  fi
  if [[ -z "$tmp" ]]; then
    print -u2 -r -- "error: mktemp failed (launcher download)"
    return 1
  fi

  print -u2 -r -- "info: downloading launcher: $url"
  if command -v curl >/dev/null 2>&1; then
    command curl -fsSL "$url" >| "$tmp" || {
      rm -f -- "$tmp" 2>/dev/null || true
      print -u2 -r -- "error: failed to download launcher via curl"
      return 1
    }
  elif command -v wget >/dev/null 2>&1; then
    command wget -qO "$tmp" "$url" || {
      rm -f -- "$tmp" 2>/dev/null || true
      print -u2 -r -- "error: failed to download launcher via wget"
      return 1
    }
  else
    rm -f -- "$tmp" 2>/dev/null || true
    print -u2 -r -- "error: missing downloader (need: curl or wget)"
    return 1
  fi

  if [[ ! -s "$tmp" ]]; then
    rm -f -- "$tmp" 2>/dev/null || true
    print -u2 -r -- "error: launcher download returned empty file"
    return 1
  fi

  command chmod 700 "$tmp" 2>/dev/null || true
  command mv -f -- "$tmp" "$auto_path" || {
    rm -f -- "$tmp" 2>/dev/null || true
    print -u2 -r -- "error: failed to install launcher to: $auto_path"
    return 1
  }

  print -u2 -r -- "info: installed launcher: $auto_path"
  print -r -- "$auto_path"
  return 0
}

# _codex_workspace_resolve_container [name|container]
# Resolve a workspace container name (auto-picks when only one exists).
_codex_workspace_resolve_container() {
  emulate -L zsh
  setopt pipe_fail

  local name="${1:-}"

  _codex_workspace_require_docker || return $?
  if ! docker info >/dev/null 2>&1; then
    print -u2 -r -- "error: docker daemon not running (start OrbStack/Docker Desktop)"
    return 1
  fi

  if [[ -n "$name" ]]; then
    local container=''
    container="$(_codex_workspace_normalize_container_name "$name")" || return 1
    _codex_workspace_require_container "$container" || return $?
    print -r -- "$container"
    return 0
  fi

  local -a containers=()
  containers=("${(@f)$(_codex_workspace_container_names)}")
  if (( ${#containers[@]} == 1 )); then
    print -r -- "${containers[1]}"
    return 0
  fi

  if (( ${#containers[@]} == 0 )); then
    print -u2 -r -- "error: no workspaces found"
  else
    print -u2 -r -- "error: multiple workspaces found; specify one:"
    _codex_workspace_print_folders "${containers[@]}"
  fi
  return 2
}

# _codex_workspace_ensure_container_running <container>
# Ensure the workspace container is running (starts it when stopped).
_codex_workspace_ensure_container_running() {
  emulate -L zsh

  local container="${1:-}"
  [[ -n "$container" ]] || return 1

  local running=''
  running="$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null || true)"
  if [[ "$running" != "true" ]]; then
    print -r -- "info: starting workspace: $container"
    docker start "$container" >/dev/null || {
      print -u2 -r -- "error: failed to start workspace: $container"
      return 1
    }
  fi

  return 0
}

# _codex_workspace_require_codex_use
# Ensure codex-use is available on the host.
_codex_workspace_require_codex_use() {
  emulate -L zsh
  setopt pipe_fail

  if typeset -f codex-use >/dev/null 2>&1; then
    return 0
  fi

  local source_file_path=''
  if [[ -f "$HOME/.config/codex_secrets/_codex-secret.zsh" ]]; then
    source_file_path="$HOME/.config/codex_secrets/_codex-secret.zsh"
  elif [[ -n "${ZSH_SCRIPT_DIR-}" && -f "${ZSH_SCRIPT_DIR}/_features/codex/_codex-secret.zsh" ]]; then
    source_file_path="${ZSH_SCRIPT_DIR}/_features/codex/_codex-secret.zsh"
  fi

  if [[ -n "$source_file_path" ]]; then
    if (( $+functions[source_file] )); then
      source_file "$source_file_path"
    else
      source "$source_file_path"
    fi
  fi

  typeset -f codex-use >/dev/null 2>&1
}

# _codex_workspace_auth_github <container> [host]
# Apply GitHub auth to an existing workspace container.
_codex_workspace_auth_github() {
  emulate -L zsh
  setopt pipe_fail

  local container="${1:?missing container}"
  local gh_host="${2:-${GITHUB_HOST:-github.com}}"

  local auth_mode="${CODEX_WORKSPACE_AUTH:-auto}"
  local env_token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  local keyring_token=''
  if command -v gh >/dev/null 2>&1; then
    keyring_token="$(env -u GH_TOKEN -u GITHUB_TOKEN gh auth token -h "$gh_host" 2>/dev/null || true)"
  fi

  local chosen_token='' chosen_source=''
  case "$auth_mode" in
    none)
      chosen_source="none"
      ;;
    env)
      chosen_token="$env_token"
      chosen_source="env"
      ;;
    gh|keyring)
      if [[ -n "$keyring_token" ]]; then
        chosen_token="$keyring_token"
        chosen_source="gh"
      else
        print -u2 -r -- "warn: CODEX_WORKSPACE_AUTH=gh but no gh keyring token found; falling back to GH_TOKEN/GITHUB_TOKEN"
        chosen_token="$env_token"
        chosen_source="env"
      fi
      ;;
    auto|"")
      if [[ -n "$keyring_token" ]]; then
        chosen_token="$keyring_token"
        chosen_source="gh"
      else
        chosen_token="$env_token"
        chosen_source="env"
      fi
      ;;
    *)
      print -u2 -r -- "error: unknown CODEX_WORKSPACE_AUTH=$auth_mode (expected: auto|gh|env|none)"
      return 2
      ;;
  esac

  if [[ -z "$chosen_token" ]]; then
    if [[ "$auth_mode" == "none" ]]; then
      print -u2 -r -- "error: CODEX_WORKSPACE_AUTH=none; no token to apply"
    else
      print -u2 -r -- "error: no GitHub token found (gh keyring or GH_TOKEN/GITHUB_TOKEN)"
    fi
    print -u2 -r -- "hint: run 'gh auth login' or export GH_TOKEN/GITHUB_TOKEN"
    return 1
  fi

  _codex_workspace_ensure_container_running "$container" || return $?

  print -r -- "auth: github -> $container ($gh_host; source=$chosen_source)"
  # Use a non-login shell (`bash -c`) to avoid login logout hooks (e.g. bash_logout)
  # turning a successful auth update into a non-zero exit status.
  if ! print -r -- "$chosen_token" | docker exec -i -u codex "$container" bash -c '
    set -euo pipefail
    host="${1:-github.com}"
    IFS= read -r token || exit 2
    [[ -n "$token" ]] || exit 2

    if command -v gh >/dev/null 2>&1; then
      printf "%s\n" "$token" | gh auth login --hostname "$host" --with-token >/dev/null 2>&1 || true
      gh auth setup-git --hostname "$host" --force >/dev/null 2>&1 || gh auth setup-git --hostname "$host" >/dev/null 2>&1 || true
      gh config set git_protocol https -h "$host" 2>/dev/null || gh config set git_protocol https 2>/dev/null || true
      exit 0
    fi

    if command -v git >/dev/null 2>&1; then
      token_file="$HOME/.codex-env/gh.token"
      mkdir -p "${token_file%/*}"
      printf "%s\n" "$token" >| "$token_file"
      chmod 600 "$token_file" 2>/dev/null || true
      git config --global "credential.https://${host}.helper" \
        "!f() { echo username=x-access-token; echo password=\$(cat \"$token_file\"); }; f"
    fi
  ' -- "$gh_host"; then
    print -u2 -r -- "error: failed to update GitHub auth in $container"
    return 1
  fi

  if [[ "$chosen_source" == "gh" || "$chosen_source" == "env" ]]; then
    typeset -g CODEX_WORKSPACE_AUTH="$chosen_source"
  fi

  return 0
}

# _codex_workspace_auth_codex <container> [profile]
# Apply Codex auth to an existing workspace container.
_codex_workspace_auth_codex() {
  emulate -L zsh
  setopt pipe_fail

  local container="${1:?missing container}"
  local profile="${2-}"

  if [[ -z "$profile" ]]; then
    profile="${CODEX_WORKSPACE_CODEX_PROFILE:-}"
  fi

  if [[ -n "$profile" ]]; then
    if [[ "$profile" == *'/'* || "$profile" == *'..'* || "$profile" == *[[:space:]]* ]]; then
      print -u2 -r -- "error: invalid codex profile name: $profile"
      return 2
    fi

    typeset -g CODEX_WORKSPACE_CODEX_PROFILE="$profile"
    if _codex_workspace_require_codex_use; then
      codex-use "$profile" || {
        print -u2 -r -- "warn: failed to update host codex auth (codex-use $profile)"
      }
    else
      print -u2 -r -- "warn: codex-use not available on host; skipping host auth update"
    fi

    _codex_workspace_ensure_container_running "$container" || return $?

    if ! docker exec -u codex "$container" zsh -lc '
      profile="${1:?missing profile}"
      if ! typeset -f codex-use >/dev/null 2>&1; then
        if [[ -f /opt/zsh-kit/scripts/_features/codex/_codex-secret.zsh ]]; then
          source /opt/zsh-kit/scripts/_features/codex/_codex-secret.zsh
        fi
      fi
      codex-use "$profile"
    ' -- "$profile" >/dev/null 2>&1; then
      print -u2 -r -- "error: failed to apply codex profile in $container"
      print -u2 -r -- "hint: ensure codex secrets are mounted (recreate without --no-secrets)"
      return 1
    fi

    print -r -- "auth: codex -> $container (profile=$profile)"
    return 0
  fi

  local auth_file="${CODEX_AUTH_FILE:-$HOME/.codex/auth.json}"
  if [[ ! -f "$auth_file" ]]; then
    print -u2 -r -- "error: codex auth file not found: $auth_file"
    print -u2 -r -- "hint: set CODEX_WORKSPACE_CODEX_PROFILE or run codex-use <profile> first"
    return 1
  fi

  _codex_workspace_ensure_container_running "$container" || return $?
  if ! command cat -- "$auth_file" | docker exec -i -u codex "$container" bash -c '
    set -euo pipefail
    target="${CODEX_AUTH_FILE:-$HOME/.codex/auth.json}"
    [[ -n "$target" ]] || target="$HOME/.codex/auth.json"
    mkdir -p "$(dirname "$target")"
    rm -f -- "$target"
    umask 077
    cat > "$target"
  '; then
    print -u2 -r -- "error: failed to sync codex auth into $container"
    print -u2 -r -- "hint: check CODEX_AUTH_FILE inside the container and ensure it is writable by user 'codex'"
    return 1
  fi
  print -r -- "auth: codex -> $container (synced auth file)"
  return 0
}

# codex-workspace-auth <provider> [options] [<name|container>]
# Update auth for an existing workspace container.
codex-workspace-auth() {
  emulate -L zsh
  setopt pipe_fail

  local provider="${1:-}"
  shift 2>/dev/null || true

  local container_arg=''
  local profile=''
  local gh_host=''
  local key=''
  local -i want_help=0

  while (( $# > 0 )); do
    case "$1" in
      -h|--help)
        want_help=1
        shift
        ;;
      --container)
        container_arg="${2-}"
        shift 2 2>/dev/null || true
        ;;
      --container=*)
        container_arg="${1#*=}"
        shift
        ;;
      --name)
        container_arg="${2-}"
        shift 2 2>/dev/null || true
        ;;
      --name=*)
        container_arg="${1#*=}"
        shift
        ;;
      --profile)
        profile="${2-}"
        shift 2 2>/dev/null || true
        ;;
      --profile=*)
        profile="${1#*=}"
        shift
        ;;
      --host)
        gh_host="${2-}"
        shift 2 2>/dev/null || true
        ;;
      --host=*)
        gh_host="${1#*=}"
        shift
        ;;
      --key)
        key="${2-}"
        shift 2 2>/dev/null || true
        ;;
      --key=*)
        key="${1#*=}"
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        print -u2 -r -- "error: unknown option: $1"
        return 2
        ;;
      *)
        if [[ -z "$container_arg" ]]; then
          container_arg="$1"
          shift
        else
          print -u2 -r -- "error: unexpected arg: $1"
          return 2
        fi
        ;;
    esac
  done

  if [[ -z "$provider" || "$provider" == "-h" || "$provider" == "--help" || $want_help -eq 1 ]]; then
    cat <<'EOF'
usage:
  codex-workspace auth codex [--profile <name>] [--container <name|container>]
  codex-workspace auth github [--host <host>] [--container <name|container>]
  codex-workspace auth gpg [--key <keyid|fingerprint>] [--container <name|container>]

notes:
  - GitHub auth uses CODEX_WORKSPACE_AUTH (auto|gh|env|none) and host gh keyring or GH_TOKEN.
  - Codex auth uses CODEX_WORKSPACE_CODEX_PROFILE when set; otherwise syncs CODEX_AUTH_FILE.
  - GPG auth exports the host secret key and imports it into the container.
EOF
    return 0
  fi

  local container=''
  container="$(_codex_workspace_resolve_container "$container_arg")" || return $?

  case "$provider" in
    codex)
      _codex_workspace_auth_codex "$container" "$profile"
      return $?
      ;;
    github)
      _codex_workspace_auth_github "$container" "$gh_host"
      return $?
      ;;
    gpg)
      _codex_workspace_auth_gpg "$container" "$key"
      return $?
      ;;
    *)
      print -u2 -r -- "error: unknown auth provider: $provider"
      print -u2 -r -- "hint: expected: codex|github|gpg"
      return 2
      ;;
  esac
}

# codex-workspace-exec [--root] [--user <user>] <name|container> [--] [cmd...]
# Exec into a workspace container (default: zsh).
codex-workspace-exec() {
  emulate -L zsh
  setopt pipe_fail

  if (( $# == 0 )); then
    cat <<'EOF'
usage: codex-workspace exec [--root] [--user <user>] <name|container> [--] [cmd...]

Exec into a workspace container (default: zsh).

Notes:
  - Options must appear before the container name.
  - Uses `docker exec -it` when stdin+stdout are TTYs; otherwise uses `-i`.
EOF
    return 0
  fi

  local -i want_help=0
  local -i want_root=0
  local user='codex'

  while (( $# > 0 )); do
    case "$1" in
      -h|--help)
        want_help=1
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
        shift
        break
        ;;
      -*)
        print -u2 -r -- "error: unknown option: $1"
        return 2
        ;;
      *)
        break
        ;;
    esac
  done

  if (( want_help )); then
    cat <<'EOF'
usage: codex-workspace exec [--root] [--user <user>] <name|container> [--] [cmd...]

Exec into a workspace container (default: zsh).

Notes:
  - Options must appear before the container name.
  - Uses `docker exec -it` when stdin+stdout are TTYs; otherwise uses `-i`.
EOF
    return 0
  fi

  local name="${1:-}"
  if [[ -z "$name" ]]; then
    print -u2 -r -- "error: missing workspace name/container"
    print -u2 -r -- "hint: codex-workspace exec <container>"
    return 2
  fi
  shift 1 2>/dev/null || true

  local -a cmd=()
  cmd=("$@")
  if (( ${#cmd[@]} == 0 )); then
    cmd=(zsh)
  fi

  if (( want_root )); then
    user='root'
  fi

  _codex_workspace_require_docker || return $?
  if ! docker info >/dev/null 2>&1; then
    print -u2 -r -- "error: docker daemon not running (start OrbStack/Docker Desktop)"
    return 1
  fi

  local container=''
  container="$(_codex_workspace_normalize_container_name "$name")" || return 1
  _codex_workspace_require_container "$container" || return $?

  local container_status=''
  container_status="$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || true)"
  if [[ "$container_status" != "running" ]]; then
    print -r -- "+ docker start $container"
    docker start "$container" >/dev/null || return 1
  fi

  local -a docker_exec=()
  docker_exec=(exec -u "$user")
  if [[ -t 0 && -t 1 ]]; then
    docker_exec+=(-it)
  elif [[ -t 0 ]]; then
    docker_exec+=(-i)
  fi

  docker_exec+=("$container")
  docker_exec+=("${cmd[@]}")

  command docker "${docker_exec[@]}"
}

# codex-workspace-tunnel [--name <tunnel_name>] [--detach] <name|container>
# Start a VS Code tunnel inside a workspace container.
codex-workspace-tunnel() {
  emulate -L zsh
  setopt pipe_fail

  if (( $# == 0 )); then
    cat <<'EOF'
usage: codex-workspace-tunnel [--name <tunnel_name>] [--detach] <name|container>

Start a VS Code tunnel inside a workspace container.

Notes:
  - VS Code tunnel names are limited to 20 characters.
  - Default naming strips the workspace timestamp (e.g., -YYYYMMDD-HHMMSS) and auto-shortens when needed.
  - Override the name with --name or CODEX_WORKSPACE_TUNNEL_NAME.
  - Options may appear before or after the container name.
EOF
    return 0
  fi

  local name=''
  local detach=0
  local tunnel_name="${CODEX_WORKSPACE_TUNNEL_NAME:-}"
  local -a extra_args=()
  local -i want_help=0
  while (( $# > 0 )); do
    case "$1" in
      -h|--help)
        want_help=1
        shift
        ;;
      --detach)
        detach=1
        shift
        ;;
      --name)
        tunnel_name="${2:-}"
        if [[ -z "$tunnel_name" ]]; then
          print -u2 -r -- "error: --name requires a value"
          return 2
        fi
        shift 2 2>/dev/null || true
        ;;
      --name=*)
        tunnel_name="${1#*=}"
        if [[ -z "$tunnel_name" ]]; then
          print -u2 -r -- "error: --name requires a value"
          return 2
        fi
        shift
        ;;
      --)
        shift
        while (( $# > 0 )); do
          extra_args+=("$1")
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
usage: codex-workspace-tunnel [--name <tunnel_name>] [--detach] <name|container>

Start a VS Code tunnel inside a workspace container.

Notes:
  - VS Code tunnel names are limited to 20 characters.
  - Default naming strips the workspace timestamp (e.g., -YYYYMMDD-HHMMSS) and auto-shortens when needed.
  - Override the name with --name or CODEX_WORKSPACE_TUNNEL_NAME.
  - Options may appear before or after the container name.
EOF
    return 0
  fi

  if [[ -z "$name" ]]; then
    print -u2 -r -- "error: missing workspace name/container"
    print -u2 -r -- "hint: codex-workspace tunnel <container> [--detach]"
    return 2
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

  local container_status=''
  container_status="$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || true)"
  if [[ "$container_status" != "running" ]]; then
    print -r -- "+ docker start $container"
    docker start "$container" >/dev/null || return 1
  fi

  if ! docker exec -u codex "$container" bash -lc 'command -v code >/dev/null 2>&1'; then
    print -u2 -r -- "error: missing 'code' in container (build with INSTALL_VSCODE=1)"
    return 1
  fi

  if [[ -z "$tunnel_name" ]]; then
    tunnel_name="$(_codex_workspace_tunnel_default_name "$container")" || return 1
  else
    tunnel_name="$(_codex_workspace_tunnel_name_sanitize "$tunnel_name")"
  fi

  local -i max_len=20
  if (( ${#tunnel_name} > max_len )); then
    print -u2 -r -- "error: VS Code tunnel name too long (${#tunnel_name} > ${max_len}): $tunnel_name"
    print -u2 -r -- "hint: pass a shorter one via: codex-workspace tunnel $container --name <short>"
    return 2
  fi

  local log_path="/home/codex/.codex-env/logs/code-tunnel.log"
  if docker exec -u codex "$container" bash -lc 'pgrep -fa "[c]ode-tunnel tunnel|[c]ode tunnel" >/dev/null 2>&1'; then
    print -u2 -r -- "warn: code tunnel already running in $container"
    print -r -- "status:"
    docker exec -u codex "$container" bash -lc "code tunnel status 2>/dev/null || true"
    print -r -- "log: $log_path"
    print -r -- "tail: docker exec -it $container bash -lc 'tail -f $log_path'"
    return 0
  fi

  if (( detach )); then
    docker exec -u codex "$container" bash -lc 'mkdir -p "$(dirname "$1")" && : >"$1"' _ "$log_path" >/dev/null 2>&1 || true
    docker exec -u codex -d "$container" bash -lc 'code tunnel --accept-server-license-terms --name "$1" >"$2" 2>&1' _ "$tunnel_name" "$log_path"
    print -r -- "started: code tunnel ($tunnel_name) in $container"
    print -r -- "status:"
    sleep 1
    docker exec -u codex "$container" bash -lc "code tunnel status 2>/dev/null || true"
    print -r -- "log: $log_path"
    print -r -- "tail: docker exec -it $container bash -lc 'tail -f $log_path'"
    return 0
  fi

  print -r -- "Starting VS Code tunnel (name: $tunnel_name)."
  print -r -- "If this is the first run, follow the device-code login prompts."
  docker exec -u codex -it "$container" code tunnel --accept-server-license-terms --name "$tunnel_name"
}

# codex-workspace <subcommand> [args...]
# Host entrypoint for creating and managing Codex workspace containers.
codex-workspace() {
  emulate -L zsh
  setopt pipe_fail

  local arg1="${1:-}"

  case "$arg1" in
    ""|-h|--help)
      _codex_workspace_usage
      return 0
      ;;
    auth)
      shift 1 2>/dev/null || true
      codex-workspace-auth "$@"
      return $?
      ;;
    ls)
      shift 1 2>/dev/null || true
      codex-workspace-list "$@"
      return $?
      ;;
    list)
      print -u2 -r -- "error: subcommand removed: list"
      print -u2 -r -- "hint: use: codex-workspace ls"
      return 2
      ;;
    create)
      shift 1 2>/dev/null || true
      ;;
    rm)
      shift 1 2>/dev/null || true
      codex-workspace-rm "$@"
      return $?
      ;;
    remove)
      print -u2 -r -- "error: subcommand removed: remove"
      print -u2 -r -- "hint: use: codex-workspace rm"
      return 2
      ;;
    delete)
      print -u2 -r -- "error: subcommand removed: delete"
      print -u2 -r -- "hint: use: codex-workspace rm --all"
      return 2
      ;;
    exec)
      shift 1 2>/dev/null || true
      codex-workspace-exec "$@"
      return $?
      ;;
    reset)
      shift 1 2>/dev/null || true
      codex-workspace-reset "$@"
      return $?
      ;;
    tunnel)
      shift 1 2>/dev/null || true
      codex-workspace-tunnel "$@"
      return $?
      ;;
    *)
      print -u2 -r -- "error: unknown subcommand: $arg1"
      print -u2 -r -- "hint: expected: auth|create|ls|rm|exec|reset|tunnel"
      print -u2 -r -- "hint: codex-workspace create [--private-repo ...] [repo...]"
      _codex_workspace_usage
      return 2
      ;;
  esac

  local -a repos=()
  local private_repo_raw="${CODEX_WORKSPACE_PRIVATE_REPO-}"
  local -i no_extras=0
  local -i no_work_repos=0
  local -i want_help=0
  local workspace_name=''
  local codex_profile="${CODEX_WORKSPACE_CODEX_PROFILE-}"
  local -i want_gpg_import=0
  local gpg_key="${CODEX_WORKSPACE_GPG_KEY-}"

  local gpg_mode="${CODEX_WORKSPACE_GPG:-none}"
  case "$gpg_mode" in
    none|false|"")
      want_gpg_import=0
      ;;
    import|true)
      want_gpg_import=1
      ;;
    *)
      print -u2 -r -- "error: CODEX_WORKSPACE_GPG must be import|none (got: $gpg_mode)"
      return 2
      ;;
  esac

  while (( $# > 0 )); do
    case "$1" in
      -h|--help)
        want_help=1
        shift
        ;;
      --name)
        workspace_name="${2-}"
        shift 2 2>/dev/null || break
        ;;
      --name=*)
        workspace_name="${1#*=}"
        shift
        ;;
      --private-repo)
        private_repo_raw="${2-}"
        shift 2 2>/dev/null || break
        ;;
      --private-repo=*)
        private_repo_raw="${1#*=}"
        shift
        ;;
      --codex-profile)
        codex_profile="${2-}"
        shift 2 2>/dev/null || break
        ;;
      --codex-profile=*)
        codex_profile="${1#*=}"
        shift
        ;;
      --no-extras)
        no_extras=1
        shift
        ;;
      --no-work-repos)
        no_work_repos=1
        shift
        ;;
      --gpg)
        want_gpg_import=1
        shift
        ;;
      --no-gpg)
        want_gpg_import=0
        shift
        ;;
      --gpg-key)
        gpg_key="${2-}"
        want_gpg_import=1
        shift 2 2>/dev/null || true
        ;;
      --gpg-key=*)
        gpg_key="${1#*=}"
        want_gpg_import=1
        shift
        ;;
      --)
        shift
        while (( $# > 0 )); do
          repos+=("$1")
          shift
        done
        ;;
      -*)
        print -u2 -r -- "error: unknown option: $1"
        return 2
        ;;
      *)
        repos+=("$1")
        shift
        ;;
    esac
  done

  if (( want_help )); then
    _codex_workspace_usage
    return 0
  fi

  if [[ -n "${codex_profile//[[:space:]]/}" ]]; then
    if [[ "$codex_profile" == *'/'* || "$codex_profile" == *'..'* || "$codex_profile" == *[[:space:]]* ]]; then
      print -u2 -r -- "error: invalid codex profile name: $codex_profile"
      return 2
    fi
    if [[ ! -d "$HOME/.config/codex_secrets" ]]; then
      print -u2 -r -- "error: codex secrets dir not found: $HOME/.config/codex_secrets"
      print -u2 -r -- "hint: unset CODEX_WORKSPACE_CODEX_PROFILE or create secrets dir"
      return 1
    fi
  else
    codex_profile=''
  fi

  local -a codex_profile_arg=()
  if [[ -n "$codex_profile" ]]; then
    codex_profile_arg=(--codex-profile "$codex_profile")
  fi

  if (( no_work_repos )); then
    if (( ${#repos[@]} > 0 )); then
      print -u2 -r -- "error: --no-work-repos does not accept repo args"
      print -u2 -r -- "got: ${(j: :)repos}"
      return 2
    fi
    if [[ -z "${workspace_name//[[:space:]]/}" ]]; then
      print -u2 -r -- "error: --no-work-repos requires --name <name>"
      return 2
    fi
  else
    if (( ${#repos[@]} == 0 )); then
      local detected_repo=''
      detected_repo="$(_codex_workspace_repo_default_from_cwd 2>/dev/null || true)"
      if [[ -z "$detected_repo" ]]; then
        _codex_workspace_usage
        return 0
      fi
      repos=("$detected_repo")
    fi
  fi

  local repo=''
  if (( no_work_repos == 0 )); then
    repo="${repos[1]-}"
  fi

  local launcher="${CODEX_WORKSPACE_LAUNCHER-}"
  local -i launcher_explicit=0
  if [[ -n "${launcher//[[:space:]]/}" ]]; then
    launcher_explicit=1
  else
    launcher="$(_codex_workspace_launcher_default_path)"
  fi
  launcher="$(_codex_workspace_ensure_launcher "$launcher" "$launcher_explicit")" || {
    if (( launcher_explicit )); then
      return 1
    fi
    print -u2 -r -- "hint: set CODEX_WORKSPACE_LAUNCHER to a local launcher path"
    print -u2 -r -- "hint: or set CODEX_WORKSPACE_LAUNCHER_URL to override the download URL"
    return 1
  }

  if (( no_work_repos )); then
    local launcher_help=''
    launcher_help="$("$launcher" --help 2>/dev/null || true)"
    if [[ "$launcher_help" != *"--no-clone"* ]]; then
      print -u2 -r -- "error: launcher does not support --no-clone (required by --no-work-repos)"
      print -u2 -r -- "hint: update the launcher script or set CODEX_WORKSPACE_LAUNCHER to a newer version"
      return 1
    fi
  fi

  if ! command -v docker >/dev/null 2>&1; then
    print -u2 -r -- "error: docker not found on host"
    return 1
  fi

  if ! docker info >/dev/null 2>&1; then
    print -u2 -r -- "error: docker daemon not running (start OrbStack/Docker Desktop)"
    return 1
  fi

  local tmp_out=''
  tmp_out="$(mktemp "${TMPDIR:-/tmp}/codex-workspace.XXXXXX" 2>/dev/null || true)"
  if [[ -z "$tmp_out" ]]; then
    tmp_out="$(mktemp -t codex-workspace.XXXXXX 2>/dev/null || true)"
  fi
  if [[ -z "$tmp_out" ]]; then
    print -u2 -r -- "error: mktemp failed"
    return 1
  fi

  # Opinionated defaults:
  # - No host bind-mounts for workspace/config (works with remote Docker hosts),
  #   except codex secrets (local path bind-mount).
  # - Prefer host `gh` keyring auth (works across orgs) when available; else use GH_TOKEN/GITHUB_TOKEN.
  # - Seed host ~/.config by copying (snapshot), excluding codex-kit + zsh.
  local gh_host="github.com"
  local gh_owner_repo=''
  if (( no_work_repos )); then
    if [[ -n "${private_repo_raw//[[:space:]]/}" ]]; then
      local private_repo_input="${private_repo_raw//[[:space:]]/}"
      if _codex_workspace_parse_repo_spec "$private_repo_input" "$gh_host"; then
        gh_host="${reply[1]-$gh_host}"
        gh_owner_repo="${reply[4]-}"
      fi
    fi
  else
    gh_owner_repo="$repo"
    if [[ "$repo" == http://* || "$repo" == https://* ]]; then
      local without_scheme="${repo#*://}"
      gh_host="${without_scheme%%/*}"
      gh_owner_repo="${without_scheme#*/}"
    elif [[ "$repo" == git@*:* ]]; then
      local without_user="${repo#git@}"
      gh_host="${without_user%%:*}"
      gh_owner_repo="${repo#*:}"
    elif [[ "$repo" == ssh://git@*/* ]]; then
      local without_prefix="${repo#ssh://git@}"
      gh_host="${without_prefix%%/*}"
      gh_owner_repo="${without_prefix#*/}"
    fi
    gh_owner_repo="${gh_owner_repo%.git}"
    gh_owner_repo="${gh_owner_repo%/}"
    if [[ "$gh_owner_repo" == */*/* ]]; then
      local owner="${gh_owner_repo%%/*}"
      local rest="${gh_owner_repo#*/}"
      local name="${rest%%/*}"
      gh_owner_repo="${owner}/${name}"
    fi
  fi

  local auth_mode="${CODEX_WORKSPACE_AUTH:-auto}"
  local env_token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  local keyring_token=''
  if command -v gh >/dev/null 2>&1; then
    keyring_token="$(env -u GH_TOKEN -u GITHUB_TOKEN gh auth token -h "$gh_host" 2>/dev/null || true)"
  fi

  local chosen_token=''
  local chosen_source=''
  case "$auth_mode" in
    none)
      chosen_token=""
      chosen_source="none"
      ;;
    env)
      chosen_token="$env_token"
      chosen_source="env"
      ;;
    gh|keyring)
      if [[ -n "$keyring_token" ]]; then
        chosen_token="$keyring_token"
        chosen_source="gh"
      else
        print -u2 -r -- "warn: CODEX_WORKSPACE_AUTH=gh but no gh keyring token found; falling back to GH_TOKEN/GITHUB_TOKEN"
        chosen_token="$env_token"
        chosen_source="env"
      fi
      ;;
    auto|"")
      if [[ -n "$keyring_token" && "$gh_owner_repo" == */* ]]; then
        if GH_TOKEN="$keyring_token" GITHUB_TOKEN="" gh api --hostname "$gh_host" --silent "repos/${gh_owner_repo}" >/dev/null 2>&1; then
          chosen_token="$keyring_token"
          chosen_source="gh"
        else
          chosen_token="$env_token"
          chosen_source="env"
        fi
      elif [[ -n "$keyring_token" ]]; then
        chosen_token="$keyring_token"
        chosen_source="gh"
      else
        chosen_token="$env_token"
        chosen_source="env"
      fi
      ;;
    *)
      print -u2 -r -- "error: unknown CODEX_WORKSPACE_AUTH=$auth_mode (expected: auto|gh|env|none)"
      return 2
      ;;
  esac

  if [[ -n "$env_token" && -n "$keyring_token" && "$chosen_source" == "gh" ]]; then
    print -u2 -r -- "auth: using gh keyring token for $gh_host (set CODEX_WORKSPACE_AUTH=env to force GH_TOKEN)"
  fi

  if [[ -n "$chosen_token" ]]; then
    if (( no_work_repos )); then
      GH_TOKEN="$chosen_token" GITHUB_TOKEN="" "$launcher" up \
        --no-clone \
        --name "$workspace_name" \
        --host "$gh_host" \
        --secrets-dir "$HOME/.config/codex_secrets" \
        --secrets-mount /home/codex/codex_secrets \
        "${codex_profile_arg[@]}" \
        --persist-gh-token \
        --setup-git 2>&1 | tee "$tmp_out"
    else
      GH_TOKEN="$chosen_token" GITHUB_TOKEN="" "$launcher" up "$repo" \
        --secrets-dir "$HOME/.config/codex_secrets" \
        --secrets-mount /home/codex/codex_secrets \
        "${codex_profile_arg[@]}" \
        --persist-gh-token \
        --setup-git 2>&1 | tee "$tmp_out"
    fi
  else
    if (( no_work_repos )); then
      "$launcher" up \
        --no-clone \
        --name "$workspace_name" \
        --host "$gh_host" \
        --secrets-dir "$HOME/.config/codex_secrets" \
        --secrets-mount /home/codex/codex_secrets \
        "${codex_profile_arg[@]}" \
        --persist-gh-token \
        --setup-git 2>&1 | tee "$tmp_out"
    else
      "$launcher" up "$repo" \
        --secrets-dir "$HOME/.config/codex_secrets" \
        --secrets-mount /home/codex/codex_secrets \
        "${codex_profile_arg[@]}" \
        --persist-gh-token \
        --setup-git 2>&1 | tee "$tmp_out"
    fi
  fi

  local rc=$?
  local out=''
  out="$(cat "$tmp_out" 2>/dev/null || true)"
  rm -f -- "$tmp_out" 2>/dev/null || true
  [[ $rc -eq 0 ]] || return $rc

  local repo_dir=''
  repo_dir="$(print -r -- "$out" | sed -nE 's/^path:[[:space:]]*//p' | tail -n 1)"

  local container=''
  container="$(print -r -- "$out" | sed -nE 's/^workspace:[[:space:]]*//p' | tail -n 1)"
  if [[ -z "$container" ]]; then
    print -u2 -r -- "warn: failed to detect workspace container name from output"
    print -u2 -r -- "warn: skipping ~/.config snapshot and ~/.private setup"
  else
    docker exec -u codex "$container" bash -lc '
      if command -v gh >/dev/null 2>&1; then
        host="${1:-github.com}"
        gh config set git_protocol https -h "$host" 2>/dev/null || gh config set git_protocol https 2>/dev/null || true
      fi
    ' -- "$gh_host" >/dev/null 2>&1 || true

    codex-workspace-refresh-opt-repos "$container" --yes || {
      print -u2 -r -- "warn: failed to refresh /opt/codex-kit and /opt/zsh-kit in $container"
    }

    # Snapshot host ~/.config into the container (skip if already done).
    local snapshot_marker="/home/codex/.codex-env/config.snapshot.ok"
    if docker exec -u codex "$container" bash -lc "test -f '$snapshot_marker'" >/dev/null 2>&1; then
      print -r -- "snapshot: ~/.config already copied (remove $snapshot_marker in container to re-copy)"
    else
      if docker exec -u codex "$container" bash -lc 'mkdir -p "$HOME/.config" "$HOME/.codex-env" 2>/dev/null && test -w "$HOME/.config"' >/dev/null 2>&1; then
        print -r -- "+ snapshot ~/.config -> $container:/home/codex/.config (excluding codex-kit, zsh)"

        local -a tar_no_meta=()
        if command tar --no-acls -cf /dev/null -T /dev/null >/dev/null 2>&1; then
          tar_no_meta+=(--no-acls)
        fi
        if command tar --no-fflags -cf /dev/null -T /dev/null >/dev/null 2>&1; then
          tar_no_meta+=(--no-fflags)
        fi
        if command tar --no-xattrs -cf /dev/null -T /dev/null >/dev/null 2>&1; then
          tar_no_meta+=(--no-xattrs)
        fi

        COPYFILE_DISABLE=1 tar -C "$HOME" \
          "${tar_no_meta[@]}" \
          --exclude='.config/codex-kit' \
          --exclude='.config/codex_secrets' \
          --exclude='.config/zsh' \
          -cf - .config \
          | docker exec -i -u codex "$container" tar -C /home/codex -xf -
        if (( $? == 0 )); then
          docker exec -u codex "$container" bash -lc "date -u +%Y-%m-%dT%H:%M:%SZ >'$snapshot_marker'" >/dev/null || true
        else
          print -u2 -r -- "warn: failed to snapshot ~/.config into $container"
        fi
      else
        print -u2 -r -- "warn: $container:/home/codex/.config is not writable (maybe created with --config-dir :ro mount)"
        print -u2 -r -- "warn: re-create the workspace to switch to snapshot mode (rm --volumes, then re-run)"
      fi
    fi

    if (( no_extras == 0 )); then
      if [[ -n "${private_repo_raw//[[:space:]]/}" ]]; then
        local private_repo_input="${private_repo_raw//[[:space:]]/}"
        local -a private_parsed=()
        if ! _codex_workspace_parse_repo_spec "$private_repo_input" "$gh_host"; then
          print -u2 -r -- "warn: invalid private repo (expected OWNER/REPO or URL): $private_repo_raw"
        else
          private_parsed=("${reply[@]}")
          local private_owner_repo="${private_parsed[4]-}"
          local private_repo_url="${private_parsed[5]-}"

          # Pull ~/.private from a dedicated repo and wire it into zsh-kit.
          docker exec -u codex "$container" bash -lc '
            set -euo pipefail
            repo_url="${1:?missing repo_url}"
            owner_repo="${2:?missing owner_repo}"
            target="$HOME/.private"

            if [[ -d "$target/.git" ]]; then
              printf "%s\n" "+ pull ${owner_repo} -> ~/.private"
              git -C "$target" pull --ff-only || true
              exit 0
            fi

            if [[ -e "$target" ]]; then
              printf "%s\n" "warn: $target exists but is not a git repo; skipping clone" >&2
              exit 0
            fi

            printf "%s\n" "+ clone ${owner_repo} -> ~/.private"
            GIT_TERMINAL_PROMPT=0 git clone --progress "$repo_url" "$target"
          ' -- "$private_repo_url" "$private_owner_repo" || {
            print -u2 -r -- "warn: failed to setup ~/.private (repo may require auth)"
          }

          # zsh-kit always loads private scripts from $ZDOTDIR/.private (ZDOTDIR=/opt/zsh-kit).
          # Keep the canonical repo checkout at ~/.private, and symlink zsh-kit to it.
          docker exec -u codex "$container" bash -lc '
            set -euo pipefail
            if [[ -L /opt/zsh-kit/.private ]]; then
              exit 0
            fi
            rm -rf /opt/zsh-kit/.private
            ln -s "$HOME/.private" /opt/zsh-kit/.private
          ' >/dev/null || true
        fi
      fi

      local -i i=0
      for (( i = 2; i <= ${#repos[@]}; i++ )); do
        local extra_repo_raw="${repos[i]-}"
        [[ -n "${extra_repo_raw//[[:space:]]/}" ]] || continue

        local -a extra_parsed=()
        if ! _codex_workspace_parse_repo_spec "$extra_repo_raw" "$gh_host"; then
          print -u2 -r -- "warn: invalid repo (expected OWNER/REPO or URL): $extra_repo_raw"
          continue
        fi
        extra_parsed=("${reply[@]}")

        local extra_owner="${extra_parsed[2]-}"
        local extra_name="${extra_parsed[3]-}"
        local extra_owner_repo="${extra_parsed[4]-}"
        local extra_repo_url="${extra_parsed[5]-}"
        local extra_dest="/work/${extra_owner}/${extra_name}"

        docker exec -u codex "$container" bash -lc '
          set -euo pipefail
          repo_url="${1:?missing repo_url}"
          owner_repo="${2:?missing owner_repo}"
          dest="${3:?missing dest}"

          if [[ -d "${dest%/}/.git" ]]; then
            printf "%s\n" "repo already present: $dest"
            exit 0
          fi

          if [[ -e "$dest" ]]; then
            printf "%s\n" "warn: $dest exists but is not a git repo; skipping clone" >&2
            exit 0
          fi

          printf "%s\n" "+ clone ${owner_repo} -> $dest"
          mkdir -p "$(dirname "$dest")"
          GIT_TERMINAL_PROMPT=0 git clone --progress "$repo_url" "$dest"
        ' -- "$extra_repo_url" "$extra_owner_repo" "$extra_dest" || {
          print -u2 -r -- "warn: failed to clone repo: $extra_repo_raw"
        }
      done
    fi
  fi

  if (( want_gpg_import )); then
    if [[ -z "$container" ]]; then
      print -u2 -r -- "warn: --gpg enabled but workspace container name was not detected; skipping gpg import"
    else
      _codex_workspace_auth_gpg "$container" "$gpg_key" || return $?
    fi
  fi

  if [[ "$repo" == */* ]]; then
    local owner="${repo%%/*}"
    local name="${repo##*/}"
    print -r --
    print -r -- "Dev Containers:"
    print -r -- "  - Attach: Cmd+Shift+P -> Dev Containers: Attach to Running Container..."
    if [[ -n "$repo_dir" ]]; then
      print -r -- "  - Open:   ${repo_dir}"
    else
      print -r -- "  - Open:   /work/${owner}/${name}"
    fi

    if [[ -n "$container" && -n "$repo_dir" ]]; then
      local docker_context="default"
      docker_context="$(docker context show 2>/dev/null || true)"
      [[ -n "$docker_context" ]] || docker_context="default"

      local authority_json="{\"containerName\":\"/${container}\",\"settings\":{\"context\":\"${docker_context}\"}}"
      local authority_hex=''
      if command -v python3 >/dev/null 2>&1; then
        authority_hex="$(python3 -c 'import sys,binascii; print(binascii.hexlify(sys.argv[1].encode()).decode())' "$authority_json" 2>/dev/null || true)"
      fi

      if [[ -n "$authority_hex" ]]; then
        local folder_uri="vscode-remote://attached-container+${authority_hex}${repo_dir}"
        print -r -- "  - VS Code: code --new-window --folder-uri \"${folder_uri}\""
        local open_vscode_enabled="${CODEX_WORKSPACE_OPEN_VSCODE_ENABLED:-}"
        if [[ -z "$open_vscode_enabled" && -n "${CODEX_WORKSPACE_OPEN_VSCODE:-}" ]]; then
          print -u2 -r -- "warn: CODEX_WORKSPACE_OPEN_VSCODE is deprecated; use CODEX_WORKSPACE_OPEN_VSCODE_ENABLED=true|false"
          open_vscode_enabled="true"
        fi
        case "$open_vscode_enabled" in
          ""|false)
            ;;
          true)
            if command -v code >/dev/null 2>&1; then
              code --new-window --folder-uri "${folder_uri}" >/dev/null 2>&1 || true
            else
              print -u2 -r -- "warn: VS Code CLI (code) not found; open the folder URI manually"
            fi
            ;;
          *)
            print -u2 -r -- "error: CODEX_WORKSPACE_OPEN_VSCODE_ENABLED must be true or false (got: $open_vscode_enabled)"
            return 2
            ;;
        esac
      fi
    fi
  else
    print -r --
    print -r -- "Dev Containers:"
    print -r -- "  - Attach: Cmd+Shift+P -> Dev Containers: Attach to Running Container..."
  fi
}
