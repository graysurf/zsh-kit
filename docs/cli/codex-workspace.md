# 🧰 codex-workspace: Dev Containers Workspace Helper

`codex-workspace` is an opt-in feature (`ZSH_FEATURES=codex-workspace`) that adds:

- `codex-workspace create`: start a workspace container for a repo (Dev Containers mode)
- `cw`: alias of `codex-workspace`
- `codex-workspace list`: list workspace containers
- `codex-workspace tunnel`: open a tunnel for a running workspace (auto-shortens tunnel name to meet VS Code limits)
- `codex-workspace rm` / `codex-workspace-rm`: remove a workspace container + named volumes
- `codex-workspace delete --all`: remove all workspace containers + named volumes
- `codex-workspace-refresh-opt-repos`: refresh `/opt/codex-kit` + `/opt/zsh-kit` inside the container
- `codex-workspace-reset-repo`: hard reset a single repo inside the container
- `codex-workspace-reset-work-repos`: hard reset all repos under `/work` inside the container
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
codex-workspace create --no-work-repos --name ws-foo
codex-workspace create --no-work-repos --name ws-foo --private-repo OWNER/PRIVATE_REPO

codex-workspace list

codex-workspace rm <name|container> [--yes]
codex-workspace delete --all [--yes]
codex-workspace tunnel <container> [--name <tunnel_name>] [--detach]
```

Notes:

- `codex-workspace` (without subcommand) prints help.
- Repo args are optional when inside a git repo (defaults to `git remote get-url origin`), unless `--no-work-repos` is used.
- When passing multiple repos, the first seeds the workspace; remaining repos are cloned under `/work` in order.
- Use `--no-extras` to disable cloning `~/.private` and additional repos under `/work` (seed repo is still cloned).
- Use `--no-work-repos` to skip cloning any repos into `/work` (including the default-from-CWD `origin`);
  requires `--name` and rejects repo args. `--private-repo` still runs unless `--no-extras` is also set.
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

- `CODEX_WORKSPACE_LAUNCHER`: override the host launcher path (default: `~/.config/codex-kit/docker/codex-env/bin/codex-workspace`)
- `CODEX_WORKSPACE_LAUNCHER_AUTO_DOWNLOAD`: `true|false` (default: `true`)
- `CODEX_WORKSPACE_LAUNCHER_URL`: override the launcher download URL (optional)
- `CODEX_WORKSPACE_LAUNCHER_AUTO_PATH`: override the launcher auto-install path (optional)
- `CODEX_WORKSPACE_AUTH`: `auto|gh|env|none` (default: `auto`)
- `CODEX_WORKSPACE_PREFIX`: container name prefix used by `codex-workspace-rm` and completion (default: `codex-ws`)
- `CODEX_WORKSPACE_OPEN_VSCODE_ENABLED`: `true|false` (optional)
- `CODEX_WORKSPACE_TUNNEL_NAME`: override `codex-workspace tunnel` name (must be <= 20 chars)

---

## Linux/macOS notes

- The host `~/.config` snapshot uses `tar` and only enables metadata-suppression flags (`--no-acls`, `--no-xattrs`, `--no-fflags`) when supported by the host `tar` (GNU tar on Ubuntu, bsdtar on macOS).
