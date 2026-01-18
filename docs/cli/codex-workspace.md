# 🧰 codex-workspace: Dev Containers Workspace Helper

`codex-workspace` is an opt-in feature (`ZSH_FEATURES=codex-workspace`) that adds:

- `codex-workspace`: start a workspace container for a repo (Dev Containers mode)
- `codex-workspace rm` / `codex-workspace-rm`: remove a workspace container + named volumes
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
codex-workspace OWNER/REPO
codex-workspace https://github.com/OWNER/REPO

codex-workspace rm <name|container> [--yes]
```

---

## Optional: seed container `~/.private`

If you want the container to clone/pull a repo into `~/.private` (and symlink `/opt/zsh-kit/.private` to it):

```bash
export CODEX_WORKSPACE_PRIVATE_REPO="OWNER/PRIVATE_REPO"
codex-workspace OWNER/REPO

# or:
codex-workspace --private-repo OWNER/PRIVATE_REPO OWNER/REPO
```

Accepted formats:

- `OWNER/REPO`
- a git URL (https / ssh)

For `OWNER/REPO`, the host is derived from the target repo input (default: `github.com`).

---

## Env

- `CODEX_WORKSPACE_LAUNCHER`: override the host launcher path (default: `~/.config/codex-kit/docker/codex-env/bin/codex-workspace`)
- `CODEX_WORKSPACE_AUTH`: `auto|gh|env|none` (default: `auto`)
- `CODEX_WORKSPACE_PREFIX`: container name prefix used by `codex-workspace-rm` and completion (default: `codex-ws`)
- `CODEX_WORKSPACE_OPEN_VSCODE_ENABLED`: `true|false` (optional)

---

## Linux/macOS notes

- The host `~/.config` snapshot uses `tar` and only enables metadata-suppression flags (`--no-acls`, `--no-xattrs`, `--no-fflags`) when supported by the host `tar` (GNU tar on Ubuntu, bsdtar on macOS).

