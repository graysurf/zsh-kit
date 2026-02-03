# 🗣️ Interactive Runtime Scripts (`scripts/interactive/`)

This folder contains interactive-only initialization for your Zsh session (prompt, key bindings,
completion setup, and plugin hooks).

It is loaded **after** the general `scripts/` modules (see `bootstrap/bootstrap.zsh`), and is
expected to run only in an interactive environment.

Primary files:

- `runtime.zsh`: prompt + runtime behaviors (zoxide, starship, options)
- `hotkeys.zsh`: ZLE widgets and key bindings (including `fzf-cli` hotkeys)
- `completion.zsh`: completion bootstrap (`compinit`) and completion-related fixes
- `plugin-hooks.zsh`: post-plugin-load hooks / overrides

---

## 🧭 Directory Navigation Enhancer: Zoxide

Initializes zoxide (if installed), providing `z` / `zi` commands.

This config also overrides zoxide’s internal `__zoxide_cd` to show an `eza` listing after a
successful jump (interactive TTY only).

```zsh
if command -v zoxide >/dev/null 2>&1; then
  source <(zoxide init zsh)

  __zoxide_cd() {
    builtin cd -- "$1" || return

    if [[ -o interactive && -t 1 ]]; then
      printf "\n📁 Now in: %s\n\n" "$PWD"
      if command -v eza >/dev/null 2>&1; then
        eza -alh --icons --group-directories-first --time-style=iso || :
      fi
    fi

    return 0
  }
fi
```

### Usage

- Jump: `z <query>`
- Interactive search: `zi [query]` (runs `zoxide query --interactive`)
- Interactive completion (cursor at end of line): `z <query><Space><Tab>` (press Space, release, then press Tab)

Note:

- zoxide registers its completion via `compdef`.
- Since zoxide is initialized before `compinit` in this repo, `completion.zsh` re-registers zoxide’s
  completion after `compinit` to make `<Space><Tab>` reliable.

---

## 💫 Prompt: Starship

If `config/starship.toml` is found, it will be loaded as the custom Starship configuration:

```zsh
export STARSHIP_CONFIG="$ZSH_CONFIG_DIR/starship.toml"
source <(starship init zsh)
```

This enables a context-aware, language-sensitive prompt with Git integration, status coloring, and
path simplification.

---

## 🔑 Shell Behavior & Keybindings

Zsh options are configured for consistent pattern matching and case-insensitive globbing:

```zsh
setopt nocaseglob nocasematch extendedglob
```

### History Search

Arrow keys (`↑ ↓`) and `j/k` in vi-mode support substring-based history search:

```zsh
bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down
```

### fzf-cli Hotkeys

If `fzf-cli` is installed, ZLE widgets are defined in `hotkeys.zsh`:

- `Ctrl+F`: `fzf-cli-launcher-widget` (pick a subcommand via `fzf` and execute it)
- `Ctrl+T`: `fzf-cli-def-widget` (run `fzf-cli def [query]`)
- `Ctrl+G`: `fzf-cli-git-commit-widget` (run `fzf-cli git-commit [--snapshot] [query]`)
- `Ctrl+R`: `fzf-history-widget` (fzf history insert; no execution)

Note: `Ctrl+F` overrides the default Emacs-style cursor movement binding.

### Codex CLI Hotkeys

If `codex-cli` is installed, extra widgets may be available:

- `Ctrl+U`: `codex-cli diag rate-limits --all --async` (query rate limits for all configured accounts)
