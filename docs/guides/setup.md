# zsh-kit Setup

This guide covers installing this repo as the Zsh config directory for a Mac.
The intended destination is:

```text
$HOME/.config/zsh
```

The safe setup path is dry-run first, write startup files only after review, and
install third-party CLI tools as a separate explicit step.

## Install On A New Mac

Install Homebrew first if it is not already available, then install the
`zsh-kit` setup CLI from `nils-cli`:

```bash
brew tap sympoies/tap
brew install nils-cli
```

Run a dry-run before mutating shell startup files:

```bash
zsh-kit setup \
  --repo https://github.com/graysurf/zsh-kit.git \
  --write-zshenv \
  --install-tools skip \
  --dry-run
```

Apply the setup after reviewing the dry-run:

```bash
zsh-kit setup \
  --repo https://github.com/graysurf/zsh-kit.git \
  --write-zshenv \
  --install-tools skip \
  --apply
```

Forward optional feature flags with `--features`:

```bash
zsh-kit setup \
  --repo https://github.com/graysurf/zsh-kit.git \
  --write-zshenv \
  --install-tools skip \
  --features docker,opencode \
  --apply
```

## Existing `~/.zshenv`

`zsh-kit setup --write-zshenv` writes a managed `~/.zshenv` that exports
`ZDOTDIR` and sources this repo's `.zshenv`. If the user already has an
unmanaged `~/.zshenv`, setup stops with a conflict instead of overwriting it.

Keep the existing file and add this snippet manually:

```bash
export ZDOTDIR="$HOME/.config/zsh"
export ZSH_FEATURES="${ZSH_FEATURES:-}"
if [[ -r "$ZDOTDIR/.zshenv" ]]; then
  source "$ZDOTDIR/.zshenv"
fi
```

Use `--force` only after backing up or intentionally replacing the existing
file:

```bash
zsh-kit setup \
  --repo https://github.com/graysurf/zsh-kit.git \
  --write-zshenv \
  --install-tools skip \
  --apply \
  --force
```

## Runtime Setup With `zsh-kit`

The repository exposes a stable setup hook at
`bootstrap/zsh-kit-setup.zsh`. The nils-cli `zsh-kit` binary clones or updates
the repository, validates this hook, and dispatches the repo-owned setup
behavior.

For repository-local validation, the hook can be run without private mutations:

```bash
bootstrap/zsh-kit-setup.zsh --features docker --install-tools skip --dry-run --smoke
```

## Agent-Driven Setup

For agent-driven setup from a checked-out copy of this repository, the project
exposes `.agents/scripts/bootstrap.sh` for the runtime-kit `$bootstrap` skill.
The dispatcher defaults to a dry-run:

```bash
agent-run exec --cwd "$HOME/.config/zsh" -- ./.agents/scripts/bootstrap.sh --dry-run
```

After reviewing the plan, apply the same setup:

```bash
agent-run exec --cwd "$HOME/.config/zsh" -- ./.agents/scripts/bootstrap.sh --apply
```

Pass `--repo https://github.com/graysurf/zsh-kit.git` when the checked-out
repository's `origin` is SSH but the target machine should install over HTTPS.
The bootstrap dispatcher defaults to `--write-zshenv`, `--install-tools skip`,
and a post-setup smoke check when the destination hook exists.

## Tool Installation Policy

The safe default is `--install-tools skip`, which does not install or modify
third-party CLI tools. After the shell setup is in place, preview required tools:

```bash
cd "$HOME/.config/zsh"
./install-tools.zsh --dry-run
```

Install missing required tools only after reviewing the list:

```bash
./install-tools.zsh --yes
```

Use `./install-tools.zsh --all --yes` for optional tools, and
`./install-tools.zsh --update-brew --yes` only when you intentionally want to
run `brew update` first. The installer does not run `brew upgrade`.

Existing commands already on `PATH` are treated as installed even when they came
from another package manager such as Homebrew, `mise`, `asdf`, `pipx`, `cargo`,
or a vendor installer.

## Optional Features (`ZSH_FEATURES`)

Some modules are disabled by default and are not sourced unless opted in. Enable
them by setting `ZSH_FEATURES` in your home `~/.zshenv` before sourcing this
repo:

```bash
export ZSH_FEATURES="docker,opencode"
```

Current features:

- `opencode`: enables `opencode-tools` and `opencode-tools` completion
- `docker`: enables `docker-tools`, `docker-aliases`, `docker-tools`
  completion, and `docker` completion

Why the extra `source`? `.zshenv` is the first startup file, so setting
`ZDOTDIR` inside `~/.zshenv` does not automatically make Zsh restart and load
`$ZDOTDIR/.zshenv`.

Zsh will now load:

- `$ZDOTDIR/.zshenv` for all shells
- `$ZDOTDIR/.zprofile` for login shells
- `$ZDOTDIR/.zshrc` for interactive shells

For more details, see [startup-files.md](startup-files.md).

Make sure that `.zshrc` sources the bootstrap loader:

```bash
source "$ZDOTDIR/bootstrap/bootstrap.zsh"
```

This initializes all scripts in order through the
`load_script_group_ordered()` and `load_script_group()` loader helpers.

## Machine-Local Environment

Machine-local environment defaults belong in ignored private files. The tracked
`.zshenv` sources `.private/zshenv.zsh` only when present, so personal paths,
company hosts, tokens, and agent runtime overrides do not ship to other
machines.

The `.private/zshenv.zsh` file is optional. Other Macs do not need it to run
the bootstrap.

For a private overlay shared between hosts, keep its Git checkout outside this
repository and link it into the runtime slot:

```sh
git clone git@github.com:graysurf/local-scripts.git \
  "$HOME/Project/graysurf/local-scripts"
ln -s ../../Project/graysurf/local-scripts "$HOME/.config/zsh/.private"
```

The relative target is identical on macOS and Linux. Run Git, worktree, and
sync operations against `~/Project/graysurf/local-scripts`, not through the
compatibility link. Startup reports a broken `.private` symlink instead of
silently creating a replacement directory.
