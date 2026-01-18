# Host helper to start a Codex workspace container (Dev Containers mode) (feature: codex-workspace).
#
# Usage:
#   codex-workspace [--private-repo <owner/repo|URL>] <owner/repo|URL>
#
# Example:
#   codex-workspace OWNER/REPO
#
# Env:
# - CODEX_WORKSPACE_PRIVATE_REPO: optional; clone/pull this repo into ~/.private inside the container.

codex-workspace() {
  emulate -L zsh
  setopt pipe_fail

  local arg1="${1:-}"

  case "$arg1" in
    rm|remove|delete)
      shift 1 2>/dev/null || true
      codex-workspace-rm "$@"
      return $?
      ;;
  esac

  local repo=''
  local private_repo_raw="${CODEX_WORKSPACE_PRIVATE_REPO-}"
  local -a extra_args=()
  local -i want_help=0

  while (( $# > 0 )); do
    case "$1" in
      -h|--help)
        want_help=1
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
      --)
        shift
        while (( $# > 0 )); do
          if [[ -z "$repo" ]]; then
            repo="$1"
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
        if [[ -z "$repo" ]]; then
          repo="$1"
        else
          extra_args+=("$1")
        fi
        shift
        ;;
    esac
  done

  if (( want_help )) || [[ -z "$repo" ]]; then
    cat <<'EOF'
usage:
  codex-workspace [--private-repo <owner/repo|URL>] <owner/repo|URL>
  codex-workspace rm <name|container> [--yes]

example:
  codex-workspace OWNER/REPO
  codex-workspace --private-repo OWNER/PRIVATE_REPO OWNER/REPO
  CODEX_WORKSPACE_PRIVATE_REPO=OWNER/PRIVATE_REPO codex-workspace OWNER/REPO

notes:
  - Auth is automatic by default:
    - If `gh` is logged in (keyring), this function prefers that token (works better across orgs).
    - Otherwise it falls back to host GH_TOKEN/GITHUB_TOKEN.
    - Override with: CODEX_WORKSPACE_AUTH=env|gh|auto|none
  - If org SSO blocks access, run: `env -u GH_TOKEN -u GITHUB_TOKEN gh auth refresh -h github.com -s repo -s read:org`
  - VS Code: if you see "cannot find workspace /work/..." you likely attached from an existing window;
    open a new window, or run the printed `code --new-window --folder-uri ...` command.
  - To auto-open VS Code after launch: `CODEX_WORKSPACE_OPEN_VSCODE_ENABLED=true codex-workspace OWNER/REPO`
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
  fi

  if (( ${#extra_args[@]} > 0 )); then
    print -u2 -r -- "error: unexpected extra args: ${extra_args[*]}"
    return 2
  fi

  local launcher="${CODEX_WORKSPACE_LAUNCHER:-$HOME/.config/codex-kit/docker/codex-env/bin/codex-workspace}"
  if [[ ! -x "$launcher" ]]; then
    print -u2 -r -- "error: codex-kit launcher not found: $launcher"
    print -u2 -r -- "hint: expected codex-kit at: $HOME/.config/codex-kit"
    return 1
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
  local gh_owner_repo="$repo"
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

  local auth_mode="${CODEX_WORKSPACE_AUTH:-auto}"
  local env_token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  local keyring_token=""
  if command -v gh >/dev/null 2>&1; then
    keyring_token="$(env -u GH_TOKEN -u GITHUB_TOKEN gh auth token -h "$gh_host" 2>/dev/null || true)"
  fi

  local chosen_token=""
  local chosen_source=""
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
    GH_TOKEN="$chosen_token" GITHUB_TOKEN="" "$launcher" up "$repo" \
      --secrets-dir "$HOME/.config/codex_secrets" \
      --secrets-mount /home/codex/codex_secrets \
      --persist-gh-token \
      --setup-git 2>&1 | tee "$tmp_out"
  else
    "$launcher" up "$repo" \
      --secrets-dir "$HOME/.config/codex_secrets" \
      --secrets-mount /home/codex/codex_secrets \
      --persist-gh-token \
      --setup-git 2>&1 | tee "$tmp_out"
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

        local tar_help=""
        tar_help="$(command tar --help 2>&1 || true)"
        local -a tar_no_meta=()
        [[ "$tar_help" == *"--no-acls"* ]] && tar_no_meta+=(--no-acls)
        [[ "$tar_help" == *"--no-fflags"* ]] && tar_no_meta+=(--no-fflags)
        [[ "$tar_help" == *"--no-xattrs"* ]] && tar_no_meta+=(--no-xattrs)

        COPYFILE_DISABLE=1 tar -C "$HOME" \
          "${tar_no_meta[@]}" \
          --exclude='.config/codex-kit' \
          --exclude='.config/codex_secrets' \
          --exclude='.config/zsh' \
          -cf - .config \
          | docker exec -i -u codex "$container" tar -C /home/codex -xf -
        docker exec -u codex "$container" bash -lc "date -u +%Y-%m-%dT%H:%M:%SZ >'$snapshot_marker'" >/dev/null || true
      else
        print -u2 -r -- "warn: $container:/home/codex/.config is not writable (maybe created with --config-dir :ro mount)"
        print -u2 -r -- "warn: re-create the workspace to switch to snapshot mode (rm --volumes, then re-run)"
      fi
    fi

    if [[ -n "${private_repo_raw//[[:space:]]/}" ]]; then
      local private_repo="${private_repo_raw//[[:space:]]/}"
      private_repo="${private_repo%.git}"
      private_repo="${private_repo%/}"

      local private_repo_url=""
      if [[ "$private_repo" == http://* || "$private_repo" == https://* || "$private_repo" == git@*:* || "$private_repo" == ssh://git@*/* ]]; then
        private_repo_url="$private_repo"
      elif [[ "$private_repo" == */* ]]; then
        if [[ "$private_repo" == */*/* ]]; then
          local p_owner="${private_repo%%/*}"
          local p_rest="${private_repo#*/}"
          local p_name="${p_rest%%/*}"
          private_repo="${p_owner}/${p_name}"
        fi
        private_repo_url="https://${gh_host}/${private_repo}.git"
      else
        print -u2 -r -- "warn: invalid private repo (expected OWNER/REPO or URL): $private_repo_raw"
      fi

      if [[ -n "$private_repo_url" ]]; then
        # Pull ~/.private from a dedicated repo and wire it into zsh-kit.
        print -r -- "+ ensure container ~/.private from configured repo"
        docker exec -u codex "$container" bash -lc '
          set -euo pipefail
          repo_url="${1:?missing repo_url}"
          target="$HOME/.private"

          if [[ -d "$target/.git" ]]; then
            git -C "$target" pull --ff-only || true
            exit 0
          fi

          if [[ -e "$target" ]]; then
            printf '%s\n' "warn: $target exists but is not a git repo; skipping clone" >&2
            exit 0
          fi

          git clone "$repo_url" "$target"
        ' -- "$private_repo_url" || {
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

    if [[ -n "$container" && -n "$repo_dir" ]] && command -v code >/dev/null 2>&1; then
      local docker_context="default"
      docker_context="$(docker context show 2>/dev/null || true)"
      [[ -n "$docker_context" ]] || docker_context="default"

      local authority_json="{\"containerName\":\"/${container}\",\"settings\":{\"context\":\"${docker_context}\"}}"
      local authority_hex=""
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
            code --new-window --folder-uri "${folder_uri}" >/dev/null 2>&1 || true
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
