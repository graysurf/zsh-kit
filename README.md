# zsh-kit

A modular, self-contained Zsh environment focused on manual control, clean structure, and script-based extensibility,
with emoji-powered UX and built-in Git tools.

## ✨ Core Features

> This Zsh environment provides a clean structure and several built-in tools.

- 🌟 [Login banner](docs/guides/login-banner.md): Emoji-powered shell intro with rotating quotes
- 🧩 [Plugin System](docs/guides/plugin-system.md): Git-powered declarative loader with auto-clone and update support
- ⏳ [Progress bar utilities](docs/guides/progress-bar.md): TTY-friendly progress output for long-running commands
- 🚀 [Starship](https://starship.rs): Customized prompt with language & context awareness
- 🧭 [Zoxide](https://github.com/ajeetdsouza/zoxide): Smart directory jumping, aliased as `z`
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
│   ├── _internal/     # Internal modules (not auto-loaded; paths, wrapper generator, etc.)
│   ├── git/           # Git workflow tools and custom logic
│   └── interactive/   # Interactive shell scripts (completion, plugin hooks, etc.)
├── tests/             # Zsh test scripts (audit, regression, etc.)
├── tools/             # Standalone executable scripts or compiled helpers
└── .private/          # Local state + secrets (not for sharing)
```

## 🪄 Startup Snapshot

> Login messages include randomly selected inspirational quotes and an optional cached wttr.in weather snapshot,
> stored in local files that grow over time.

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

🍎 yourname on MacBook ~ 🐳 orbstack
08:00:00.000 ✔︎
```

To show a one-line feature summary at startup, set:

```bash
export ZSH_BOOT_FEATURES_ENABLED=true
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

### Optional Features (`ZSH_FEATURES`)

Some modules are disabled by default (not sourced; no wrappers generated).
Enable them by setting `ZSH_FEATURES` in your **home** `~/.zshenv` **before** sourcing this repo:

```bash
export ZSH_FEATURES="docker,opencode"
```

Current features:

- `opencode`: enables `opencode-tools` (plus `opencode-tools` completion)
- `docker`: enables `docker-tools` + `docker-aliases` (plus `docker-tools` + `docker` completion)

Why the extra `source`? `.zshenv` is the first startup file, so setting `ZDOTDIR` inside `~/.zshenv`
does not automatically make Zsh restart and load `$ZDOTDIR/.zshenv`.

Zsh will now load:

- `$ZDOTDIR/.zshenv` for all shells
- `$ZDOTDIR/.zprofile` for login shells
- `$ZDOTDIR/.zshrc` for interactive shells

For more details, see: [docs/guides/startup-files.md](docs/guides/startup-files.md).

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

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

This project is licensed under the MIT License. See [LICENSE](LICENSE).
Third-party plugins are fetched separately (see `config/plugins.list`) and remain under their respective upstream licenses.
