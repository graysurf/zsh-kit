# zsh-kit

A modular, self-contained Zsh environment focused on manual control, clean structure, and script-based extensibility — with emoji-powered UX and built-in Git tools.

## ✨ Core Features

> This Zsh environment provides a clean structure and several built-in tools.

- 🌟 [Login banner](docs/guides/login-banner.md): Emoji-powered shell intro with rotating quotes
- 🧩 [Plugin System](docs/guides/plugin-system.md): Git-powered declarative loader with auto-clone and update support
- 🚀 [Starship](https://starship.rs): Customized prompt with language & context awareness
- 🧭 [Zoxide](https://github.com/ajeetdsouza/zoxide): Smart directory jumping, aliased as `z`
- 🔧 Modular and lazy-friendly structure under `scripts/`
- 🧹 Centralized `cache/` and `.private/` folders for clean separation of history, state, and secrets

## 🛠 Built-in CLI Tools

> The following tools are developed as part of this environment and tightly integrated.
> Each has a dedicated documentation file and serves a focused task in the Git or shell workflow.

- 🤖 [Codex CLI helpers](docs/cli/codex-cli-helpers.md): Opt-in wrappers for Codex skills with safety gate
- 🔎 [fzf-tools](docs/cli/fzf-tools.md): Interactive fuzzy-driven launcher for files, Git, processes, and history
- 🔗 [git-open](docs/cli/git-open.md): Open repo/branch/commit/PR pages in browser
- 📂 [git-scope](docs/cli/git-scope.md): Tree-based visualizations of tracked, staged, modified, or untracked files
- 🔐 [git-lock](docs/cli/git-lock.md): Commit locking system for safe checkpoints, diffs, and tagging
- 🧰 [git-tools](docs/cli/git-tools.md): Grouped git helper router (reset/commit/branch/utils)
- 📊 [git-summary](docs/cli/git-summary.md): Author-based contribution stats over time ranges

## Structure

```text
.
├── .zshenv                               # Always-loaded env; defines core ZSH_* paths
├── .zshrc                                # Main Zsh entry; sources bootstrap/bootstrap.zsh
├── .zprofile                             # Minimal login initializer for login shells
│
├── assets/                               # Static data files
├── cache/                                # Runtime cache dir (.zcompdump, plugin update timestamps, etc.)
├── docs/                                 # Markdown documentation
│   ├── README.md                         # Documentation index
│   ├── cli/                              # User-facing commands
│   ├── guides/                           # Concepts and system behavior
│   ├── progress/                         # Implementation logs (active + archived)
│   └── templates/                        # Progress templates + glossary
│
├── bootstrap/                            # Script orchestrator and plugin logic
│   ├── 00-preload.zsh                    # Early global helpers (safe_unalias, clipboard I/O, etc.)
│   ├── define-loaders.zsh                # Base loader helpers (source_file, source_file_warn_missing, group loaders, etc.)
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
│   ├── tools.list                        # Required CLI tools declaration (tool::brew-name::comment)
│   └── tools.optional.list               # Optional CLI tools declaration (tool::brew-name::comment)
│
├── scripts/                              # Modular Zsh behavior scripts
│   ├── _completion/                      # Custom completions for CLI tools or aliases
│   ├── _internal/                        # Internal modules (not auto-loaded; paths, wrapper generator, etc.)
│   │   ├── paths.exports.zsh             # Core ZSH_* path exports
│   │   ├── paths.init.zsh                # Minimal init (ensure cache dir exists)
│   │   ├── paths.zsh                     # Convenience wrapper (exports + init)
│   │   └── wrappers.zsh                  # Cached CLI wrapper generator (for subshells)
│   ├── git/                              # Git workflow tools and custom logic
│   │   ├── git.zsh                       # General Git aliases and settings
│   │   ├── git-lock.zsh                  # Lock and restore git commits with labels
│   │   ├── git-magic.zsh                 # Composite git workflows (push, fixup, review)
│   │   ├── git-open.zsh                  # Open repo/branches/commits/PRs in browser
│   │   ├── git-scope.zsh                 # Show git changes by scope, diff, or tree
│   │   ├── git-summary.zsh               # Git contributions by author/date
│   │   ├── git-tools.zsh                 # Git aliases + CLI entrypoint (impls in tools/)
│   │   └── tools/                        # Git tool implementations (autoloaded)
│   │       ├── git-branch-cleanup.zsh    # Delete merged/squash-applied branches
│   │       ├── git-commit.zsh            # Commit context + commit-to-stash
│   │       ├── git-reset.zsh             # Reset/undo/back + reset-remote
│   │       └── git-utils.zsh             # Copy staged diff + git-root + commit hash
│   ├── interactive/                      # Interactive shell scripts (completion, plugin hooks, etc.)
│   │   ├── completion.zsh                # Completion system bootstrap (compinit, options)
│   │   ├── hotkeys.zsh                   # ZLE widgets and keybindings
│   │   ├── runtime.zsh                   # Interactive runtime (prompt, zoxide, keybindings)
│   │   └── plugin-hooks.zsh              # Plugin post-load hooks and overrides
│   ├── chrome-devtools-rdp.zsh           # Launch Chrome with remote debugging + DevTools helpers
│   ├── codex-tools.zsh                   # Codex CLI helpers
│   ├── editor.zsh                        # EDITOR + vi wrapper
│   ├── env.zsh                           # Environment variable exports and init logic
│   ├── eza.zsh                           # Aliases for eza (modern ls)
│   ├── fzf-tools.zsh                     # FZF-based UI helpers for git, files, processes, etc.
│   ├── macos.zsh                         # macOS-specific system tweaks
│   ├── builtin-overrides.zsh             # Builtin wrappers: cd/cat/history (opt-out)
│   └── shell-tools.zsh                   # Core shell helpers: reload tools, fd/bat helpers, cheat.sh
│
├── tests/                                # Zsh test scripts (audit, regression, etc.)
├── tools/                                # Standalone executable scripts or compiled helpers
└── install-tools.zsh                     # Entrypoint: bootstraps Homebrew, then runs bootstrap/install-tools.zsh
```

## 🪄 Startup Snapshot

> Login messages include randomly selected inspirational quotes and an optional cached wttr.in weather snapshot, stored in local files that grow over time.

An example Zsh startup log with this config:

```text
Weather report: Taipei City, Taiwan

       .-.      Light drizzle
      (   ).    +13(12) °C
     (___(__)   ↙ 13 km/h
      ‘ ‘ ‘ ‘   10 km
     ‘ ‘ ‘ ‘    0.7 mm
                
📜 "Focus on how far you have come in life rather than looking at the accomplishments of others." — Lolly Daskal

🌿  Thinking shell initialized. Expect consequences...

✅ Loaded 00-preload.zsh in 0ms
✅ Loaded plugins.zsh in 37ms
✅ Loaded builtin-overrides.zsh in 0ms
✅ Loaded chrome-devtools-rdp.zsh in 0ms
✅ Loaded codex-starship.zsh in 0ms
✅ Loaded codex-tools.zsh in 0ms
✅ Loaded editor.zsh in 0ms
✅ Loaded eza.zsh in 0ms
✅ Loaded fzf-tools.zsh in 1ms
✅ Loaded git-lock.zsh in 0ms
✅ Loaded git-magic.zsh in 0ms
✅ Loaded git-open.zsh in 1ms
✅ Loaded git-scope.zsh in 0ms
✅ Loaded git-summary.zsh in 3ms
✅ Loaded git.zsh in 0ms
✅ Loaded git-branch-cleanup.zsh in 0ms
✅ Loaded git-commit.zsh in 0ms
✅ Loaded git-reset.zsh in 0ms
✅ Loaded git-utils.zsh in 0ms
✅ Loaded macos.zsh in 0ms
✅ Loaded shell-tools.zsh in 0ms
✅ Loaded git-tools.zsh in 0ms
✅ Loaded env.zsh in 30ms
✅ Loaded runtime.zsh in 17ms
✅ Loaded hotkeys.zsh in 0ms
✅ Loaded plugin-hooks.zsh in 0ms
✅ Loaded completion.zsh in 219ms
✅ Loaded development.zsh (delayed) in 2ms

🍎 yourname on MacBook ~ 🐳 orbstack 🌟 sym 5h:65% W:90% 01-10 20:05
08:00:00.000 ✔︎
```

## Setup

This repo is designed to be used as your Zsh config directory via `ZDOTDIR`.

In your `~/.zshenv`, set the custom config location **and explicitly source** this repo’s `.zshenv`:

```bash
export ZDOTDIR="$HOME/.config/zsh"
if [[ -r "$ZDOTDIR/.zshenv" ]]; then
  source "$ZDOTDIR/.zshenv"
fi
```

Why the extra `source`? `.zshenv` is the first startup file, so setting `ZDOTDIR` inside `~/.zshenv`
does not automatically make Zsh restart and load `$ZDOTDIR/.zshenv`.

Zsh will now load:

- `$ZDOTDIR/.zshenv` for all shells
- `$ZDOTDIR/.zprofile` for login shells
- `$ZDOTDIR/.zshrc` for interactive shells

For more details, see: `docs/guides/startup-files.md`.

Make sure that `.zshrc` sources the bootstrap loader:

```bash
source "$ZDOTDIR/bootstrap/bootstrap.zsh"
```

This will initialize all scripts in proper order via the `load_script_group_ordered()` / `load_script_group()` loader helpers.

> 🧰 This setup expects you to have your favorite CLI tools installed.  
> It won't hand-hold you, and assumes tools like `eza`, `tree`, `bat`, or `fzf` are already available.  
> If something errors out, you're probably just missing a binary — install and carry on.  

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
