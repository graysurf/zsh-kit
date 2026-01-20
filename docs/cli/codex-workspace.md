# 🧰 codex-workspace: Dev Containers Workspace Helper

`codex-workspace` is an opt-in feature (`ZSH_FEATURES=codex-workspace`) that adds:

- `codex-workspace create`: start a workspace container for a repo (Dev Containers mode)
- `cw`: alias of `codex-workspace`
- `codex-workspace ls`: list workspace containers
- `codex-workspace exec`: exec into a workspace container (default: `zsh`)
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
codex-workspace create --no-work-repos --name ws-foo
codex-workspace create --no-work-repos --name ws-foo --private-repo OWNER/PRIVATE_REPO

codex-workspace ls

codex-workspace exec <name|container> [--root]

codex-workspace rm <name|container> [--yes]
codex-workspace rm --all [--yes]
codex-workspace tunnel <container> [--name <tunnel_name>] [--detach]

codex-workspace reset repo <name|container> <repo_dir> [--ref origin/main] [--yes]
codex-workspace reset work-repos <name|container> [--root /work] [--depth 3] [--ref origin/main] [--yes]
codex-workspace reset opt-repos <name|container> [--yes]
codex-workspace reset private-repo <name|container> [--ref origin/main] [--yes]

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

- `CODEX_WORKSPACE_LAUNCHER`: override the host launcher path (default: `~/.codex/docker/codex-env/bin/codex-workspace`)
- `CODEX_WORKSPACE_LAUNCHER_AUTO_DOWNLOAD`: `true|false` (default: `true`)
- `CODEX_WORKSPACE_LAUNCHER_URL`: override the launcher download URL (optional)
- `CODEX_WORKSPACE_LAUNCHER_AUTO_PATH`: override the launcher auto-install path (optional)
- `CODEX_WORKSPACE_AUTH`: `auto|gh|env|none` (default: `auto`)
- `CODEX_WORKSPACE_PREFIX`: container name prefix used by `codex-workspace rm` and completion (default: `codex-ws`)
- `CODEX_WORKSPACE_OPEN_VSCODE_ENABLED`: `true|false` (optional; auto-runs the printed `code --folder-uri ...`)
- `CODEX_WORKSPACE_TUNNEL_NAME`: override `codex-workspace tunnel` name (must be <= 20 chars)

---

## Linux/macOS notes

- The host `~/.config` snapshot uses `tar` and only enables metadata-suppression flags (`--no-acls`, `--no-xattrs`, `--no-fflags`) when supported by the host `tar` (GNU tar on Ubuntu, bsdtar on macOS).
