# Changelog

All notable changes to this project will be documented in this file.

## v1.0.3 - 2026-01-16

### Added
- Semgrep integration with repo-local rules (`.semgrep.yaml`) via `tools/semgrep-scan.zsh` and `tools/check.zsh --semgrep` (writes JSON output under `out/semgrep/`).
- Raw prompt mode for `codex-tools` and `opencode-tools` (use `--` or `prompt` to force).
- `-a|--auto-stage` option for `codex-tools commit-with-scope` and `opencode-tools commit-with-scope` to run `semantic-commit-autostage`.

### Changed
- Hardened bootstrap/tooling by removing `eval` (wrapper bundler, plugin loader, and `install-tools.zsh`) and safely parsing `plugins.list` `KEY=VALUE` extras (including quoted values).
- Homebrew PATH setup in `.zprofile` now avoids `eval`, preserves existing entries, and prioritizes Homebrew `bin`/`sbin`.
- `git-open` now dedupes GitHub CLI PR view attempts to reduce redundant `gh pr view` calls.

### Fixed
- `open-changed-files` now no-ops cleanly when `OPEN_CHANGED_FILES_CODE_PATH` points to a missing/non-executable override.
- `git-scope` file lists and commit context paths are now more stable.
- `codex-starship` lock stale default now matches docs.

## v1.0.2 - 2026-01-14

### Added
- Zsh progress bar utilities (`progress_bar::*`) for long-running commands.
- Progress bar documentation (`docs/guides/progress-bar.md`).
- Progress bar tests to assert non-TTY silence and `--enabled` rendering.

### Changed
- Show progress output while fetching Codex rate limit usage (TTY-only; stderr).
- Sort `codex-rate-limits --all` output by `Reset (UTC)` (soonest first).

### Fixed
- Resolve progress bar module path when `ZDOTDIR` is unset (bootstrap preload).

## v1.0.1 - 2026-01-14

### Added
- CI test to fail when dotenv files are tracked by Git.

### Changed
- Ignore `.env` and `.env.*` by default (while allowing `.env.example`, `.env.sample`, `.env.template`).

### Fixed
- Prevent accidental commits of dotenv files (potential secrets) by enforcing a tracked-file guard.

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
