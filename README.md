# zsh-kit

A modular, self-contained Zsh environment focused on manual control, clean structure, and script-based extensibility — with emoji-powered UX and built-in Git tools.

## ✨ Core Features

> This Zsh environment provides a clean structure and several built-in tools.

- 🌟 [Login banner](docs/login-banner.md): Emoji-powered shell intro with rotating quotes
- 🧩 [plugin-system](docs/plugin-system.md): Git-powered declarative loader with auto-clone and update support
- 🚀 Customized [Starship](https://starship.rs) prompt with language & context awareness
- 🧭 Smart directory jumping with [Zoxide](https://github.com/ajeetdsouza/zoxide), aliased as `z`
- 🔧 Modular and lazy-friendly structure under `scripts/`
- 🧹 Centralized `cache/` and `.private/` folders for clean separation of history, state, and secrets

## 🛠 Built-in CLI Tools

> The following tools are developed as part of this environment and tightly integrated.
> Each has a dedicated documentation file and serves a focused task in the Git or shell workflow.

- 🔐 [git-lock](docs/git-lock.md): Commit locking system for safe checkpoints, diffs, and tagging
- 📂 [git-scope](docs/git-scope.md): Tree-based visualizations of tracked, staged, modified, or untracked files
- 📊 [git-summary](docs/git-summary.md): Author-based contribution stats over time ranges
- 🔎 [fzf-tools](docs/fzf-tools.md): Interactive fuzzy-driven launcher for files, Git, processes, and history
- 🤖 [codex.zsh](scripts/codex.zsh): CLI wrappers that invoke Codex skills

## Structure

```text
.
├── .zshrc                                # Main Zsh entry; sources bootstrap/bootstrap.zsh
├── .zprofile                             # Minimal login initializer for login shells
│
├── assets/                               # Static data files
├── cache/                                # Runtime cache dir (.zcompdump, plugin update timestamps, etc.)
├── docs/                                 # Markdown documentation for key modules
│
├── bootstrap/                            # Script orchestrator and plugin logic
│   ├── 00-preload.zsh                    # Early global helpers (safe_unalias, clipboard I/O, etc.)
│   ├── define-loaders.zsh                # Base loader helpers (load_script, load_group, etc.)
│   ├── bootstrap.zsh                     # Centralized Zsh entrypoint (called from .zshrc)
│   ├── plugin_fetcher.zsh                # Git-based plugin fetcher with auto-update, dry-run, and force
│   ├── plugins.zsh                       # Plugin declaration + loading logic
│   ├── quote-init.zsh                    # Show emoji + quote banner on login
│   ├── weather.zsh                       # Cached wttr.in snapshot for login weather
│   └── install-tools.zsh                 # Tool installer with dry-run and quiet support
│
├── config/                               # Configuration files for third-party tools
│   ├── plugins.list                      # Active plugin list used by loader (declarative)
│   ├── starship.toml                     # Starship prompt config (theme, modules, etc.)
│   └── tools.list                        # CLI tools declaration (tool::brew-name::comment)
│
├── scripts/                              # Modular Zsh behavior scripts
│   ├── _completion/                      # Custom completions for CLI tools or aliases
│   ├── git/                              # Git workflow tools and custom logic
│   │   ├── git-lock.zsh                  # Lock and restore git commits with labels
│   │   ├── git-magic.zsh                 # Composite git workflows (push, fixup, review)
│   │   ├── git-scope.zsh                 # Show git changes by scope, diff, or tree
│   │   ├── git-summary.zsh               # Git contributions by author/date
│   │   ├── git-tools.zsh                 # Git utilities for reset, rebase, remotes
│   │   └── git.zsh                       # General Git aliases and settings
│   ├── completion.zsh                    # Completion system bootstrap (compinit, options)
│   ├── codex.zsh                         # Codex CLI helpers
│   ├── env.zsh                           # Environment variable exports and init logic
│   ├── eza.zsh                           # Aliases for eza (modern ls)
│   ├── fzf-tools.zsh                     # FZF-based UI helpers for git, files, processes, etc.
│   ├── interactive.zsh                   # Runtime UX (prompt, zoxide, keybindings)
│   ├── macos.zsh                         # macOS-specific system tweaks
│   ├── plugin-hooks.zsh                  # Plugin post-load hooks and overrides
│   └── shell-utils.zsh                   # Core shell helpers: reload tools, cd wrappers, cheat.sh
│
├── tools/                                # Standalone executable scripts or compiled helpers
└── install-tools.zsh                     # Root-level wrapper for bootstrap/install-tools.zsh
```

## 🪄 Startup Snapshot

> Login messages include randomly selected inspirational quotes and an optional cached wttr.in weather snapshot, stored in local files that grow over time.

An example Zsh startup log with this config:

```text
Weather report: Taipei City, Taiwan

     \  /       Partly cloudy
   _ /"".-.     +25(27) °C
     \_(   ).   ↓ 14 km/h
     /(___(__)  10 km
                0.0 mm
                
📜 "Focus on how far you have come in life rather than looking at the accomplishments of others." — Lolly Daskal

🌿  Thinking shell initialized. Expect consequences...

✅ Loaded 00-preload.zsh in 3ms
✅ Loaded plugins.zsh in 89ms
✅ Loaded codex.zsh in 3ms
✅ Loaded eza.zsh in 2ms
✅ Loaded fzf-tools.zsh in 2ms
✅ Loaded git-lock.zsh in 3ms
✅ Loaded git-magic.zsh in 3ms
✅ Loaded git-scope.zsh in 2ms
✅ Loaded git-summary.zsh in 3ms
✅ Loaded git-tools.zsh in 3ms
✅ Loaded git.zsh in 3ms
✅ Loaded macos.zsh in 6ms
✅ Loaded shell-utils.zsh in 3ms
✅ Loaded env.zsh in 7ms
✅ Loaded plugin-hooks.zsh in 4ms
✅ Loaded completion.zsh in 19ms
✅ Loaded infra.sh in 4ms
✅ Loaded language.sh in 3ms
✅ Loaded development.sh (delayed) in 2ms

🍎 yourname on MacBook ~ 🐋 gke-dev 🐳 orbstack
12:00:42.133 ✔︎
```

## Setup

In your `~/.zshenv`, define the custom config location:

```bash
export ZDOTDIR="$HOME/.config/zsh"
```

Zsh will now source your config from `$ZDOTDIR/.zshrc`.

Make sure that `.zshrc` begins by sourcing the env and plugin setup:

```bash
source "$ZDOTDIR/bootstrap/bootstrap.zsh"
```

This will initialize all scripts in proper order via the `load_script_group()` system.

## 🛠 Notes

To enable quote display on login, make sure to create the following file manually:

```bash
mkdir -p $ZDOTDIR/assets
touch $ZDOTDIR/assets/quotes.txt
```

This file is **not tracked by Git** and will be automatically appended with quotes over time.  
If it does not exist, the system will fall back to a default quote.

> 🧰 This setup expects you to have your favorite CLI tools installed.  
> It won't hand-hold you, and assumes tools like `eza`, `tree`, `bat`, or `fzf` are already available.  
> If something errors out, you're probably just missing a binary — install and carry on.  

## 🤖 Codex CLI helpers

The [`scripts/codex.zsh`](scripts/codex.zsh) helpers surface four `codex-*` commands that wrap the `codex` CLI skills (`commit-with-scope`, `create-feature-pr`, `find-and-fix-bugs`, `release-workflow`) and optionally prompt for extra guidance when invoked interactively. Because each helper runs `codex exec --dangerously-bypass-approvals-and-sandbox`, the script only enables them when `CODEX_ALLOW_DANGEROUS=true`, so the environment ships with that variable unset to keep the helpers opt-in. Export the flag in your session or prefix a helper invocation with `CODEX_ALLOW_DANGEROUS=true` whenever you trust the workflow and its sandbox bypass.

## Philosophy

No magic. Fully reproducible.  
Modular by design, manual by default.

## 🧑‍💻 Why I Made This

This setup is the result of many hours spent refining my shell environment.  
It includes several tools I built myself—some small, some extensive.  
Among them, [git-magic](scripts/git/git-magic.zsh) remains my favorite and most-used.  

If there’s something you use every day, it’s worth taking the time to make it yours.

## 🪪 License

[![License: CC0-1.0](https://img.shields.io/badge/License-CC0%201.0-lightgrey.svg)](https://creativecommons.org/publicdomain/zero/1.0/)

This repository is dedicated to the public domain under the [CC0 1.0 Universal license](https://creativecommons.org/publicdomain/zero/1.0/).
You are free to copy, modify, distribute, and use any part of this work, even for commercial purposes, without asking for permission or giving credit.
