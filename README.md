# zsh-kit

A minimalist, high-performance Zsh environment with manual plugin control, emoji-powered login messages, and lazy-loaded utilities for speed and clarity.

## Features

- ⚡️ Manual plugin management (no plugin manager required)
- 🌟 Emoji-powered login messages with random quotes (via custom script)
- 🚀 Customized [Starship](https://starship.rs) prompt with language & context awareness
- 🧭 Smart directory jumping with [Zoxide](https://github.com/ajeetdsouza/zoxide), aliased as `z`
- 🔐 [git-lock](docs/git-lock.md): Commit locking system for safe checkpoints, diffs, and tagging
- 📂 [git-scope](docs/git-scope.md): Tree-based visualizations of tracked, staged, modified, or untracked files
- 🔎 [fzf-tools](docs/fzf-tools.md): Interactive fuzzy-driven launcher for files, Git, processes, and history
- 🔧 Modular and lazy-friendly structure under `scripts/`
- 🧹 Centralized `cache/` and `.private/` folders for clean separation of history, state, and secrets

## Structure

```
.zsh/
├── .private/                             # Gitignored secrets (tokens, vaults, custom overrides)
├── .zshrc                                # Main Zsh entry; sources all scripts via loader
├── .zprofile                             # Minimal login initializer (optional)
│
├── assets/                               # Static data files
│   └── quotes.txt                        # Optional: quotes for login banner
│
├── cache/                                # Runtime cache directory (e.g. zcompdump, fzf history)
│
├── config/                               # Config files for third-party tools
│   └── starship.toml                     # Starship prompt theme config
│
├── scripts/                              # Core shell logic (modularized)
│   ├── _completion/                      # Custom completion definitions
│   │
│   ├── git/                              # Git-related tools
│   │   ├── git-lock.sh                   # git-lock commit locker
│   │   ├── git-scope.sh                  # git-scope commit viewer
│   │   ├── git-tools.sh                  # Shared git utilities
│   │   └── git.sh                        # Git aliases
│   │
│   ├── completion.zsh                    # Compinit setup and fzf-tab styles
│   ├── env.sh                            # Environment variables and path setup
│   ├── eza.sh                            # Aliases for eza (ls replacement)
│   ├── fzf-tools.sh                      # Modular FZF launcher for file, git, process, and history workflows
│   ├── general.sh                        # General-purpose helpers and toggles
│   ├── iterm2_shell_integration.zsh      # Optional: iTerm2 shell integration
│   ├── login.sh                          # Banner display and login logic
│   ├── mac.sh                            # macOS-specific configuration
│   ├── plugins.sh                        # Plugin manager or manual plugin loader
│   ├── random_emoji.sh                   # Emoji picker and helpers
│   └── tools.sh                          # Miscellaneous CLI tools
│
└── tools/                                # Executable utilities
    ├── git/                              # git-related CLI frontends
    └── random_emoji_cmd.sh               # Emoji picker CLI wrapper
```

## 🪄 Startup Snapshot

> Login messages include randomly selected inspirational quotes, stored in a local file that grows over time.

An example Zsh startup log with this config:

```text
📜 "Focus on how far you have come in life rather than looking at the accomplishments of others." — Lolly Daskal

✅ Loaded eza.sh in 3ms
✅ Loaded fzf-tools.sh in 3ms
✅ Loaded general.sh in 3ms
✅ Loaded git-lock.sh in 3ms
✅ Loaded git-scope.sh in 3ms
✅ Loaded git-tools.sh in 3ms
✅ Loaded git.sh in 3ms
✅ Loaded login.sh in 3ms
✅ Loaded mac.sh in 3ms
✅ Loaded random_emoji.sh in 3ms
✅ Loaded tools.sh in 3ms
✅ Loaded language.sh in 3ms
✅ Loaded secrets.sh in 3ms
✅ Loaded ssh.sh in 3ms
✅ Loaded env.sh in 7ms
✅ Loaded plugins.sh in 53ms
✅ Loaded completion.zsh in 22ms
✅ Loaded development.sh (delayed) in 2ms

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

> 🧰 This setup expects you to have your favorite CLI tools installed.  
> It won't hand-hold you, and assumes tools like `eza`, `tree`, `bat`, or `fzf` are already available.  
> If something errors out, you're probably just missing a binary — install and carry on.

## Philosophy

No magic. Fully reproducible. Proudly minimal.
