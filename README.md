# zsh-kit

A minimalist, high-performance Zsh environment with manual plugin control, emoji-powered login messages, and lazy-loaded utilities for speed and clarity.

## Features

- ⚡️ Manual plugin management (no plugin manager required)
- 🌟 Emoji-powered login messages with random quotes (via custom script)
- 🚀 Customized [Starship](https://starship.rs) prompt with language & context awareness
- 🧭 Smart directory jumping with [Zoxide](https://github.com/ajeetdsouza/zoxide), aliased as `z`
- 🔐 [glock](docs/glock.md): Commit locking system for safe checkpoints, diffs, and tagging
- 📂 [gscope](docs/gscope.md): Tree-based visualizations of tracked, staged, modified, or untracked files
- 🔧 Modular and lazy-friendly structure under `scripts/`
- 🧹 Centralized `cache/` and `.private/` folders for clean separation of history, state, and secrets

## Structure

```
.zsh/
├── .zshrc                                # Main Zsh entry point; sources all core scripts
├── cache/                                # Runtime cache directory (e.g. zcompdump, fzf history)
├── assets/
│   └── quotes.txt                        # Optional quote file for login messages
├── scripts/                              # All core functionality is modularized here
│   ├── env.sh                            # Environment variables and path setup
│   ├── eza.sh                            # Aliases and wrappers for `eza` (ls replacement)
│   ├── fzf.sh                            # FZF configuration and key bindings
│   ├── general.sh                        # General-purpose helpers and options
│   ├── git-tools.sh                      # Git helpers: glock, gscope, summaries, etc.
│   ├── git.sh                            # Git aliases and utilities
│   ├── iterm2_shell_integration.zsh      # iTerm2 shell integration script
│   ├── login.sh                          # Login banner and quote display
│   ├── mac.sh                            # macOS-specific tweaks and paths
│   ├── plugins.sh                        # Manual plugin sourcing (no plugin manager)
│   ├── random_emoji.sh                   # Emoji utility functions
│   └── tools.sh                          # Miscellaneous CLI tools and aliases
├── config/
│   └── starship.toml                     # Starship prompt theme configuration
├── tools/
│   └── random_emoji_cmd.sh               # CLI wrapper for emoji generator (used in Starship)
├── plugins/                              # Manually installed plugin folders (e.g. fzf-tab, zsh-autosuggestions)
└── .private/                             # Gitignored secrets (tokens, vaults, custom overrides)
```

## 🪄 Startup Snapshot

> Login messages include randomly selected inspirational quotes, stored in a local file that grows over time.

An example Zsh startup log with this config:

```text
📜 "Focus on how far you have come in life rather than looking at the accomplishments of others." — Lolly Daskal

✅ Loaded env.sh in 7ms
✅ Loaded plugins.sh in 70ms
✅ Loaded iterm2_shell_integration.zsh in 7ms
✅ Loaded fzf.sh in 6ms
✅ Loaded general.sh in 4ms
✅ Loaded git-tools.sh in 4ms
✅ Loaded git.sh in 3ms
✅ Loaded login.sh in 4ms
✅ Loaded mac.sh in 3ms
✅ Loaded random_emoji.sh in 3ms
✅ Loaded tools.sh in 3ms
✅ Loaded language.sh in 3ms
✅ Loaded secrets.sh in 4ms
✅ Loaded ssh.sh in 3ms
✅ Loaded eza.sh (delayed) in 4ms

🍎 yourname on MacBook ~ 🐋 gke-dev 🐳 orbstack
12:00:42.133 ✔︎
```

## Setup

In your `~/.zshenv`, define the custom config location:

```bash
export ZDOTDIR="$HOME/.zsh"
```

Zsh will now source your config from `$ZDOTDIR/.zshrc`.

Make sure that `.zshrc` begins by sourcing the env and plugin setup:

```bash
source "$ZDOTDIR/scripts/env.sh"
source "$ZDOTDIR/scripts/plugins.sh"  # Loads plugins manually, some are lazy by design
```

This must occur **before** loading Starship or any other tooling.

## 🛠 Notes

To enable quote display on login, make sure to create the following file manually:

```bash
mkdir -p ~/.zsh/assets
touch ~/.zsh/assets/quotes.txt
```

This file is **not tracked by Git** and will be automatically appended with quotes over time.  
If it does not exist, the system will fall back to a default quote.

## Philosophy

No magic. Fully reproducible. Proudly minimal.
