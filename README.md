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
├── bootstrap/                            # Script loader and logic orchestrator
│   ├── bootstrap.sh                      # Core loader functions (load_script, load_script_group, etc.)
│   ├── init.sh                           # Centralized script entrypoint with ordered loading
│   └── plugins.sh                        # Manual plugin loader
│
├── cache/                                # Runtime cache directory (e.g. zcompdump, fzf history)
│
├── config/                               # Config files for third-party tools
│   └── starship.toml                     # Starship prompt theme config
│
├── scripts/                              # Core shell logic (modularized)
│   ├── _completion/                      # Custom completion definitions
│   │   ├── _fzf-tools
│   │   ├── _git-lock
│   │   ├── _git-scope
│   │   └── _git-summary
│   ├── git/                              # Git-related tools
│   │   ├── git-lock.sh
│   │   ├── git-magic.sh
│   │   ├── git-scope.sh
│   │   ├── git-summary.sh
│   │   ├── git-tools.sh
│   │   └── git.sh
│   ├── completion.zsh
│   ├── env.sh
│   ├── eza.sh
│   ├── fzf-tools.sh
│   ├── general.sh
│   ├── iterm2_shell_integration.zsh
│   ├── login.sh
│   ├── macos.sh
│   ├── random_emoji.sh
│   └── tools.sh
│
└── tools/                                # Executable utilities
    ├── git/
    │   ├── git-lock
    │   ├── git-scope
    │   └── git-summary
    └── random_emoji_cmd.sh
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
✅ Loaded macos.sh in 3ms
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
