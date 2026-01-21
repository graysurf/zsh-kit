# 🧰 codex-workspace: Dev Containers Workspace Helper

`codex-workspace` is an opt-in feature (`ZSH_FEATURES=codex-workspace`) that adds:

- `codex-workspace create`: start a workspace container for a repo (Dev Containers mode)
- `cw`: alias of `codex-workspace`
- `codex-workspace ls`: list workspace containers
- `codex-workspace exec`: exec into a workspace container (default: `zsh`)
- `codex-workspace rsync`: rsync files between host and workspace container
- `codex-workspace tunnel`: open a tunnel for a running workspace (auto-shortens tunnel name to meet VS Code limits)
- `codex-workspace rm`: remove workspace container(s) + named volumes (`--all` supported)
- `codex-workspace reset`: reset helpers inside a workspace container (repos, /opt, ~/.private)
- Completion for these commands (loaded during `compinit`)

---

## Enable

In `~/.zshenv` (before sourcing this repo):

```bash
export ZSH_FEATURES="codex-workspace"
```

---

## Usage

```bash
codex-workspace create OWNER/REPO
codex-workspace create https://github.com/OWNER/REPO
codex-workspace create OWNER/REPO OTHER/REPO
codex-workspace create                         # defaults to current git remote (origin)
codex-workspace create --no-extras OWNER/REPO  # create workspace for OWNER/REPO only (no ~/.private, no extra repos)
codex-workspace create --no-extras             # same, but repo inferred from current git remote (origin)
codex-workspace create --codex-profile work OWNER/REPO
codex-workspace create --gpg OWNER/REPO
codex-workspace create --gpg-key <fingerprint> OWNER/REPO
codex-workspace create --no-work-repos --name ws-foo
codex-workspace create --no-work-repos --name ws-foo --private-repo OWNER/PRIVATE_REPO

codex-workspace ls

codex-workspace exec <name|container> [--root]
codex-workspace rsync push [<name|container>] <host_src> <container_dest> [rsync_args...]
codex-workspace rsync pull [<name|container>] <container_src> <host_dest> [rsync_args...]

codex-workspace rm <name|container> [--yes]
codex-workspace rm --all [--yes]
codex-workspace tunnel <container> [--name <tunnel_name>] [--detach]

codex-workspace reset repo <name|container> <repo_dir> [--ref origin/main] [--yes]
codex-workspace reset work-repos <name|container> [--root /work] [--depth 3] [--ref origin/main] [--yes]
codex-workspace reset opt-repos <name|container> [--yes]
codex-workspace reset private-repo <name|container> [--ref origin/main] [--yes]

# Auth helpers for an existing workspace:
codex-workspace auth github [--host github.com] [--container <name|container>]
codex-workspace auth codex [--profile <name>] [--container <name|container>]
codex-workspace auth gpg [--key <keyid|fingerprint>] [--container <name|container>]

# Legacy (still supported):
codex-workspace-refresh-opt-repos <name|container> [--yes]
codex-workspace-reset-repo <name|container> <repo_dir> [--ref origin/main] [--yes]
codex-workspace-reset-work-repos <name|container> [--root /work] [--depth 3] [--ref origin/main] [--yes]
codex-workspace-reset-private-repo <name|container> [--ref origin/main] [--yes]
```

Notes:

- `codex-workspace` (without subcommand) prints help.
- Repo args are optional when inside a git repo (defaults to `git remote get-url origin`), unless `--no-work-repos` is used.
- When passing multiple repos, the first seeds the workspace; remaining repos are cloned under `/work` in order.
- Use `--no-extras` to disable cloning `~/.private` and additional repos under `/work` (seed repo is still cloned).
- Use `--no-work-repos` to skip cloning any repos into `/work` (including the default-from-CWD `origin`);
  requires `--name` and rejects repo args. `--private-repo` still runs unless `--no-extras` is also set.
- After `create`, it prints a `code --new-window --folder-uri "vscode-remote://..."` command and a clickable
  `vscode://...` link for opening the workspace path in VS Code (repo path when available; otherwise `/work`).
- For `codex-workspace reset work-repos`, `--depth` is the max repo depth under `--root` (includes shallower repos).
- If the host launcher script is missing, `codex-workspace create` auto-downloads it to:
  - `${XDG_CACHE_HOME:-~/.cache}/codex-workspace/launcher/codex-workspace`

---

## Optional: seed container `~/.private`

If you want the container to clone/pull a repo into `~/.private` (and symlink `/opt/zsh-kit/.private` to it):

```bash
export CODEX_WORKSPACE_PRIVATE_REPO="OWNER/PRIVATE_REPO"
codex-workspace create OWNER/REPO

# or:
codex-workspace create --private-repo OWNER/PRIVATE_REPO OWNER/REPO
```

Accepted formats:

- `OWNER/REPO`
- a git URL (https / ssh)

For `OWNER/REPO`, the host defaults to the target repo host when available; otherwise `github.com`.

---

## Env

All `CODEX_WORKSPACE_*` env vars supported by the host helper live in:

- `scripts/_features/codex-workspace/workspace-launcher.zsh`

| Env | Default | Values | Used by | Description |
| --- | --- | --- | --- | --- |
| `CODEX_WORKSPACE_LAUNCHER` | auto-detect: `~/.codex/docker/codex-env/bin/codex-workspace` (if executable), else `~/.config/codex-kit/docker/codex-env/bin/codex-workspace` (and auto-download to `CODEX_WORKSPACE_LAUNCHER_AUTO_PATH` when missing) | host path | `create` | Override the host launcher path. |
| `CODEX_WORKSPACE_LAUNCHER_AUTO_DOWNLOAD` | `true` | `true\|false` (empty = `true`) | `create` | Auto-download the launcher when not found and `CODEX_WORKSPACE_LAUNCHER` is not explicitly set. |
| `CODEX_WORKSPACE_LAUNCHER_AUTO_PATH` | `${XDG_CACHE_HOME:-~/.cache}/codex-workspace/launcher/codex-workspace` | host path | `create` | Where the auto-downloaded launcher is installed. |
| `CODEX_WORKSPACE_LAUNCHER_URL` | `https://raw.githubusercontent.com/graysurf/codex-kit/main/docker/codex-env/bin/codex-workspace` | `https://...` | `create` | Override the launcher download URL (GitHub `.../blob/...` URLs are normalized to `raw.githubusercontent.com`). |
| `CODEX_WORKSPACE_AUTH` | `auto` | `auto\|gh\|env\|none` (`gh` alias: `keyring`) | `create`, `auth github` | Choose the GitHub token source: `gh` keyring vs `GH_TOKEN/GITHUB_TOKEN`. |
| `CODEX_WORKSPACE_CODEX_PROFILE` | unset | profile name (no `/`, `..`, whitespace) | `create`, `auth codex` | Default Codex profile to apply via `codex-use` (requires `~/.config/codex_secrets` on host). |
| `CODEX_WORKSPACE_GPG` | `none` | `import\|none` (also accepts `true\|false`) | `create` | Default GPG import behavior (equivalent to `--gpg` / `--no-gpg`). |
| `CODEX_WORKSPACE_GPG_KEY` | unset (falls back to `git config --global user.signingkey`) | key id / fingerprint | `create`, `auth gpg` | Host signing key to export+import into the container (for `git commit -S`). |
| `CODEX_WORKSPACE_PREFIX` | `codex-ws` | string | `rm`, completion, container resolution | Workspace container name prefix. |
| `CODEX_WORKSPACE_PRIVATE_REPO` | unset | `OWNER/REPO` or git URL | `create` | Clone/pull this repo into `~/.private` inside the container (and symlink `/opt/zsh-kit/.private` to it). |
| `CODEX_WORKSPACE_TUNNEL_NAME` | derived from container name (timestamp stripped + auto-shortened, max 20 chars) | string (<= 20 chars after sanitize) | `tunnel` | Override `codex-workspace tunnel` name. |
| `CODEX_WORKSPACE_OPEN_VSCODE_ENABLED` | unset (= `false`) | `true\|false` | `create` | Auto-run the printed `code --new-window --folder-uri ...` command after `create` (requires `code` on host). |
| `CODEX_WORKSPACE_OPEN_VSCODE` | unset | any non-empty value enables auto-open | `create` | Deprecated; use `CODEX_WORKSPACE_OPEN_VSCODE_ENABLED=true\|false`. |

---

## Linux/macOS notes

- The host `~/.config` snapshot uses `tar` and only enables metadata-suppression flags (`--no-acls`, `--no-xattrs`, `--no-fflags`) when supported by the host `tar` (GNU tar on Ubuntu, bsdtar on macOS).
