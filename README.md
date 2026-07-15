# zsh-kit

A modular, self-contained Zsh environment focused on manual control, clean structure, and script-based extensibility,
with emoji-powered UX and built-in Git tools.

## ✨ Core Features

> This Zsh environment provides a clean structure and several built-in tools.

- 🌟 [Login banner](docs/guides/login-banner.md): Emoji-powered shell intro with rotating quotes
- 🧩 [Plugin System](docs/guides/plugin-system.md): Git-powered declarative loader with auto-clone and update support
- 🚀 [Starship](https://starship.rs): Customized prompt with language & context awareness
- 🧭 [Zoxide](https://github.com/ajeetdsouza/zoxide): Smart directory jumping, aliased as `z`
- 🛠 [nils-cli](https://github.com/sympoies/nils-cli) integration: native `fzf-cli` / `git-cli` workflows wired into hotkeys and aliases
- 🔧 Modular and lazy-friendly structure under `scripts/`
- 🧹 Centralized `cache/` and `.private/` folders for clean separation of history, state, and secrets

## Structure

```text
.
├── assets/            # Static data files
├── cache/             # Runtime cache dir (.zcompdump, plugin update timestamps, etc.)
├── docs/              # Markdown documentation
│   ├── cli/           # User-facing commands
│   └── guides/        # Concepts and system behavior
├── prompts/           # Shared prompt templates (used by codex/opencode helpers)
├── bootstrap/         # Script orchestrator and plugin logic
├── config/            # Configuration files for third-party tools
├── plugins/           # Vendored upstream plugins (third-party)
├── scripts/           # Modular Zsh behavior scripts
│   ├── _completion/   # Custom completions for CLI tools or aliases
│   ├── _features/     # Optional feature modules (opt-in via `ZSH_FEATURES`)
│   ├── _internal/     # Internal modules (not auto-loaded; paths, features helpers)
│   ├── git/           # Git workflow aliases (compound flows via nils-cli `git-cli`)
│   └── interactive/   # Interactive shell scripts (completion, plugin hooks, etc.)
├── tests/             # Zsh test scripts (audit, regression, etc.)
├── tools/             # Standalone executable scripts or compiled helpers
└── .private           # Ignored local overlay dir, or symlink to its canonical checkout
```

For the shared personal overlay, the physical repository lives at
`~/Project/serenvia/local-scripts` on every host. Keep `.private` as the relative
compatibility symlink `../../Project/serenvia/local-scripts`; Zsh continues to
load the logical path while Git and sync tools operate on the Project checkout.
A broken `.private` symlink is a startup error and is never replaced by a new
directory.

## 🪄 Startup Snapshot

> Login messages include randomly selected inspirational quotes and an optional cached weather snapshot
> (`weather-cli` when configured, wttr.in fallback), stored in local files that grow over time.

An example Zsh startup log with this config (`weather-cli` + `ZSH_WEATHER_CITY` configured;
the wttr.in fallback prints the classic ASCII report instead):

```text
🌦  Taipei  25~35°C  ☔ 59%  Drizzle

📜 "Focus on how far you have come in life rather than looking at the accomplishments of others." — Lolly Daskal
🌿  Thinking shell initialized. Expect consequences...

🍎 yourname on MacBook ~ 🐳 orbstack
08:00:00.000 ✔︎
```

To show a one-line feature summary at startup, set:

```bash
export ZSH_BOOT_FEATURES_ENABLED=true
```

## Setup

This repo is designed to be used as your Zsh config directory via `ZDOTDIR`.
For existing `~/.zshenv` files, agent-driven setup, optional features, and
tool installation policy, see the full setup guide:
[docs/guides/setup.md](docs/guides/setup.md).

Install Homebrew first if it is not already available, then install the setup
CLI from `nils-cli`:

```bash
brew tap sympoies/tap
brew install nils-cli
```

Preview the setup before mutating shell startup files:

```bash
zsh-kit setup \
  --repo https://github.com/graysurf/zsh-kit.git \
  --write-zshenv \
  --install-tools skip \
  --dry-run
```

Apply after reviewing the dry-run:

```bash
zsh-kit setup \
  --repo https://github.com/graysurf/zsh-kit.git \
  --write-zshenv \
  --install-tools skip \
  --apply
```

The default `--install-tools skip` does not install or modify third-party CLI
tools. Install missing tools separately after reviewing
[`docs/guides/setup.md`](docs/guides/setup.md#tool-installation-policy).

## Philosophy

No magic. Fully reproducible.  
Modular by design, manual by default.

## 🧑‍💻 Why I Made This

This setup is the result of many hours spent refining my shell environment.  
It includes several tools I built myself—some small, some extensive.  
Among them, [git-magic](scripts/git/git-magic.zsh) remains my favorite and most-used.  

If there’s something you use every day, it’s worth taking the time to make it yours.

## 🪪 License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

This project is licensed under the MIT License. See [LICENSE](LICENSE).
Third-party plugins are fetched separately (see `config/plugins.list`) and remain under their respective upstream licenses.
