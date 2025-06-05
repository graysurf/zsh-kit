# zsh-kit

🎯 A carefully crafted Zsh configuration system

This setup **does not use any plugin manager** (like Oh My Zsh, Antigen, or zinit).  
All plugins are manually sourced with controlled loading for maximum transparency, speed, and flexibility.

## Features

- ⚡️ Manual plugin management (no plugin manager required)
- 🌟 Emoji-powered login messages (via custom script)
- 🚀 Customized [Starship](https://starship.rs) prompt with language & context awareness
- 📁 Fast directory jumping with [zsh-z](https://github.com/agkozak/zsh-z)
- 🔧 Modular and lazy-friendly structure under `scripts/`
- 🧹 Centralized `cache/` and `.private/` folders for clean separation of history, state, and secrets

## Directory structure

```bash
.config/zsh/
├── scripts/        # Your modular Zsh setup scripts (env.sh, git.sh, etc.)
├── plugins/        # Manually cloned Zsh plugins (no plugin manager)
├── cache/          # Compdump, .z, history, and other volatile files
├── .private/       # Machine-specific secrets or overrides (not tracked)
├── .zshrc          # Loads everything
├── .zprofile       # Login-specific setup (optional)
```

## Getting started

```bash
git clone https://github.com/YOUR-USERNAME/zsh-kit ~/.config/zsh
cd ~/.config/zsh

# Link .zshrc to home if not already
ln -s ~/.config/zsh/.zshrc ~/.zshrc
```

👉 Customize your environment in `scripts/`, and keep secrets in `.private/`.  
No magic. Fully reproducible. Proudly minimal.
