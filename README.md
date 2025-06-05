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

## 🛠 Setup Notes

To enable quote display on login, make sure to create the following file manually:

```bash
mkdir -p ~/.zsh/assets
touch ~/.zsh/assets/quotes.txt
