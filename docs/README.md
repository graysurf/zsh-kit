# 📚 Documentation Index

This folder contains the living documentation for this Zsh environment.

Use this page as the entry point, then jump into either the **guides** (how the system is designed)
or the **CLI docs** (how to use shipped commands).

---

## 🧭 Structure

```text
docs/
├── README.md                 # This index
├── guides/                   # Concepts and system behavior
├── cli/                      # User-facing commands
├── progress/                 # Implementation logs (active + archived)
└── templates/                # Progress file templates + glossary
```

---

## 🧠 Guides

- [`guides/startup-files.md`](guides/startup-files.md) — Zsh startup file roles (`.zshenv` / `.zprofile` / `.zshrc`) + `ZDOTDIR`
- [`guides/plugin-system.md`](guides/plugin-system.md) — Declarative plugin loader + Git-based fetcher
- [`guides/login-banner.md`](guides/login-banner.md) — Quote + emoji + optional weather banner
- [`guides/fzf-def-docs.md`](guides/fzf-def-docs.md) — Docblock guidelines for `fzf-tools def` / `fzf-tools function` / `fzf-tools alias`

---

## 🛠 CLI Docs

- [`cli/codex-cli-helpers.md`](cli/codex-cli-helpers.md) — Opt-in wrappers for Codex CLI skills (feature: `codex`)
- [`cli/codex-starship.md`](cli/codex-starship.md) — Codex rate limits line for Starship (`codex-starship`; feature: `codex`)
- [`cli/opencode-cli-helpers.md`](cli/opencode-cli-helpers.md) — Opt-in prompt helpers for OpenCode (feature: `opencode`)
- [`cli/fzf-tools.md`](cli/fzf-tools.md) — FZF-based interactive launcher (`fzf-tools`)
- [`cli/git-open.md`](cli/git-open.md) — Open repo/branch/commit/PR pages in browser (`git-open`)
- [`cli/git-scope.md`](cli/git-scope.md) — Tree-based viewers for git status / commits (`git-scope`)
- [`cli/git-lock.md`](cli/git-lock.md) — Commit locking checkpoints (`git-lock`)
- [`cli/git-tools.md`](cli/git-tools.md) — Router for grouped git helpers (`git-tools`)
- [`cli/git-summary.md`](cli/git-summary.md) — Contribution stats (`git-summary`)
- [`cli/open-changed-files.md`](cli/open-changed-files.md) — Open changed files in VS Code (`open-changed-files`)

---

## 🗂 Progress System

- [`progress/README.md`](progress/README.md) — How to write and archive progress logs
- [`templates/PROGRESS_TEMPLATE.md`](templates/PROGRESS_TEMPLATE.md) — Progress template
- [`templates/PROGRESS_GLOSSARY.md`](templates/PROGRESS_GLOSSARY.md) — Naming + terminology rules
