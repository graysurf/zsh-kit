# zsh-kit

A minimalist, high-performance Zsh environment with manual plugin control, emoji-powered login messages, and lazy-loaded utilities for speed and clarity.

## Features

- ⚡️ Manual plugin management (no plugin manager required)
- 🌟 Emoji-powered login messages (via custom script)
- 🚀 Customized [Starship](https://starship.rs) prompt with language & context awareness
- 📁 Fast directory jumping with [zsh-z](https://github.com/agkozak/zsh-z)
- 🔧 Modular and lazy-friendly structure under `scripts/`
- 🧹 Centralized `cache/` and `.private/` folders for clean separation of history, state, and secrets

## Structure

```
.zsh/
├── assets/
│   └── quotes.txt            # Fallback quote source
├── cache/                    # Runtime cache (e.g. zcompdump)
├── scripts/
│   ├── login.sh              # Login quote logic (with lazy API update)
│   ├── random_emoji.sh       # Emoji generator
│   ├── plugins.sh            # Manually sourced plugins
│   ├── ...
├── .private/                 # Gitignored; for vaults, keys, tokens
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
source "$ZDOTDIR/scripts/plugins.sh"
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
