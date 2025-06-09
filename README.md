# zsh-kit

A minimalist, high-performance Zsh environment with manual plugin control, emoji-powered login messages, and lazy-loaded utilities for speed and clarity.

## Features

- ⚡️ Manual plugin management (no plugin manager required)
- 🌟 Emoji-powered login messages with random quotes (via custom script)
- 🚀 Customized [Starship](https://starship.rs) prompt with language & context awareness
- 🧭 Smart directory jumping with [Zoxide](https://github.com/ajeetdsouza/zoxide), aliased as `z`
- 🔐 [git-lock](docs/git-lock.md): Commit locking system for safe checkpoints, diffs, and tagging
- 📂 [git-scope](docs/git-scope.md): Tree-based visualizations of tracked, staged, modified, or untracked files
- 📊 [git-summary](docs/git-summary.md): Author-based contribution stats over time ranges
- 🔎 [fzf-tools](docs/fzf-tools.md): Interactive fuzzy-driven launcher for files, Git, processes, and history
- 🧠 Unified UX with previewable shell functions, aliases, and env vars
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
├── bootstrap/                            # Script loader and logic orchestrator
│   ├── bootstrap.sh                      # Core loader functions (load_script, load_script_group, etc.)
│   ├── init.sh                           # Centralized script entrypoint with ordered loading
│   └── plugins.sh                        # Manual plugin loader for third-party or custom plugins
│
├── cache/                                # Runtime cache directory (e.g. zcompdump, fzf history)
│
├── config/                               # Config files for third-party tools
│   └── starship.toml                     # Starship prompt theme config
│
├── scripts/                              # Core shell logic (modularized)
│   ├── _completion/                      # Custom completion definitions
│   ├── git/                              # Git-related tools
│   │   ├── git-lock.sh                   # Save, restore, diff, and tag Git commits via custom lock labels (safe checkpoints)
│   │   ├── git-magic.sh                  # Composite git aliases for commit, push, amend, and GitHub open workflows
│   │   ├── git-scope.sh                  # Visualize git changes as colored file lists and directory trees by scope or commit
│   │   ├── git-summary.sh                # Author-based Git contribution summary over custom or preset date ranges
│   │   ├── git-tools.sh                  # Git utility functions and aliases for reset, navigation, and remote operations
│   │   └── git.sh                        # Base-level git command customizations
│   ├── completion.zsh                    # Zsh completion framework setup
│   ├── env.sh                            # Environment variables and export logic
│   ├── eza.sh                            # Wrapper and aliases for modern ls replacement (eza)
│   ├── fzf-tools.sh                      # Interactive FZF utilities for files, git, processes, env, aliases, and shell functions
│   ├── general.sh                        # General purpose shell utilities and aliases
│   ├── iterm2_shell_integration.zsh      # iTerm2 shell integration script (for prompt triggers, etc.)
│   ├── login.sh                          # Display a random login quote with emoji, and asynchronously fetch new quotes for future use
│   ├── macos.sh                          # macOS-specific settings and system tweaks
│   ├── random_emoji.sh                   # Random emoji + quote generator for banner use
│   └── tools.sh                          # Miscellaneous helper functions for reloading, editing config, navigation, and cheat.sh lookup
│
└── tools/                                # Executable utilities (e.g. CLI tools written in any language)
```

## 🪄 Startup Snapshot

> Login messages include randomly selected inspirational quotes, stored in a local file that grows over time.

An example Zsh startup log with this config:

```text
📜 "Focus on how far you have come in life rather than looking at the accomplishments of others." — Lolly Daskal

✅ Loaded plugins.sh in 89ms
✅ Loaded eza.sh in 2ms
✅ Loaded fzf-tools.sh in 2ms
✅ Loaded general.sh in 3ms
✅ Loaded git-lock.sh in 3ms
✅ Loaded git-magic.sh in 3ms
✅ Loaded git-scope.sh in 2ms
✅ Loaded git-summary.sh in 3ms
✅ Loaded git-tools.sh in 3ms
✅ Loaded git.sh in 3ms
✅ Loaded login.sh in 2ms
✅ Loaded macos.sh in 6ms
✅ Loaded random_emoji.sh in 3ms
✅ Loaded shell-utils.sh in 3ms
✅ Loaded env.sh in 7ms
✅ Loaded completion.zsh in 19ms
✅ Loaded infra.sh in 4ms
✅ Loaded language.sh in 3ms
✅ Loaded local.sh in 2ms
✅ Loaded rytass.sh in 4ms
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
source "$ZDOTDIR/bootstrap/init.sh"
```

This will initialize all scripts in proper order via the `load_script_group()` system.

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
