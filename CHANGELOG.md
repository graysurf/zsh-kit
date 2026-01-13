# Changelog
## v1.0.0 - 2026-01-13

### Added
- Modular, self-contained Zsh environment with ordered bootstrap loading and a structured `scripts/` layout.
- Git-powered plugin system with declarative config and auto-clone / update support.
- Built-in CLI tools: `fzf-tools`, `git-open`, `git-scope`, `git-lock`, `git-tools`, `git-summary`.
- Optional feature modules via `ZSH_FEATURES`, including Codex CLI helpers and OpenCode prompt helpers.

### Changed
- First-party code released under the MIT license (vendored plugins remain under upstream licenses).
- Codex helper commit workflows delegate to the `semantic-commit` skill for consistency.

### Fixed
- Improved Codex rate limit display reliability and stale lock cleanup in starship integration.
- Enhanced `fzf-tools` git status preview and selection behavior for staged/unstaged changes.
