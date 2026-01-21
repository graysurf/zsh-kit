# Changelog

All notable changes to this project will be documented in this file.

## v2.1.1 - 2026-01-21

### Added
- `codex-workspace auth` subcommand with `--codex-profile` support.
- `codex-workspace` can import GPG signing keys during workspace setup.
- `codex-workspace` supports VS Code clickable links and shell-native hex encoding.
- `git-tools git-pick ci` helper for selecting CI branches.
- `codex-use` completion can display Codex secret rate limits.

### Changed
- `codex-tools` CLI is reorganized into command groups.
- Default auth file path is now `~/.codex/auth.json`.
- `codex-secret rate-limits` display always uses the secret filename.
- Workspace workflow enforces stricter `typeset` initializers and updates tooling.

### Fixed
- `codex-workspace` auth sync reliability and git credential helper handling.
- `codex-rate-limits-async` stability plus stderr/hotkey handling.
- `git-lock` parses tag arguments correctly.
- `progress-bar` avoids wrapped updates.
- `fzf-tools` uses the correct awk preview shebang.
- `GPG_TTY` detection is more reliable.
- Workspace launcher tests no longer auto-open VS Code.

## v2.1.0 - 2026-01-19

### Added
- `codex-workspace`: Dev Containers workspace management helper (`create/ls/exec/tunnel/rm/reset`) with completion (`ZSH_FEATURES=codex-workspace`).
- `docker-tools` feature module (`docker-tools`, `docker-aliases`) plus cached completion for `docker` and `docker-compose` (`ZSH_FEATURES=docker`).
- Completion lint/check: `tools/check.zsh --completions` (runs `tools/check-completions.zsh`).
- `git-tools commit context-json` (alias: `gccj`) to generate a JSON manifest + staged patch for commit context.
- Linux tool lists for `install-tools` (`config/tools.linux*.list` + `config/tools.linux.apt.list`).

### Changed
- Bootstrap supports structured debug levels and optional feature summary at startup.
- Commit helper tooling adds git validation and improved auto-staging flows.
- Starship prompt includes the container module.
- Optional tool lists include image processing tools.

### Fixed
- `codex-workspace reset` supports resetting repos at any depth up to `--depth` (default: 3) and keeps stdin attached for container scripts.
- `CODEX_SECRET_DIR` override handling is more robust across Codex helpers.
- Completion coverage and flag sets are more consistent (including alias coverage and `git push` flags).
- Async worker pool now waits reliably for worker PIDs (`scripts/async-pool.zsh`).

## v2.0.1 - 2026-01-17

### Added
- Async rate limits checker for all Codex secrets: `codex-rate-limits-async` (alias: `crla`).
- Generic async worker pool utility: `scripts/async-pool.zsh` (`async_pool::map`).
- ANSI/color helper utilities: `scripts/ansi-utils.zsh`.

### Changed
- `codex-tools rate-limits` supports `--async/--jobs` and ANSI-colored percent cells (TTY default; respects `NO_COLOR`).
- `bundle-wrapper.zsh` detects already-bundled inputs (copy fast-path) and parses wrapper `sources` arrays more robustly.
- Homebrew bootstrap no longer uses `eval "$(brew shellenv)"`.
- `fzf-tools` default file search depth (`FZF_FILE_MAX_DEPTH`) is now 10.

### Fixed
- Default `ZDOTDIR` when unset to keep scripts working in minimal environments.
- `git-back-checkout` now handles branch names with slashes when parsing reflog history.
- `git-open pr` passes the branch selector to `gh pr view` for more reliable PR opening.
- Builtin `cd` override now returns success even if the directory listing tool fails (and falls back to `ls`).
- `git-commit-context` uses more portable `mktemp` handling and reliably cleans up temp files.

## v2.0.0 - 2026-01-16

### Added
- Boolean env audit tooling: `tools/audit-env-bools.zsh` and `tools/check.zsh --env-bools` (runs in `--all`).
- Shared strict boolean parser helper: `zsh_env::is_true` (in `bootstrap/00-preload.zsh`).
- `codex-starship --is-enabled` for Starship `when` gating.

### Changed
- Project-owned boolean env flags accept only `true|false` (case-insensitive); invalid values warn to stderr and behave as `false`.
- Project-owned boolean env flags are standardized to `*_ENABLED` naming (no legacy aliases).
- Builtin overrides env flag is now `SHELL_UTILS_BUILTIN_OVERRIDES_ENABLED` (default: `true`).

### Fixed
- Avoid stderr during smoke-load when `bootstrap/00-preload.zsh` is sourced multiple times.
- Avoid env-bools audit false positives when scanning the audit script itself.

### Removed
- Support for legacy boolean vocab (`0/1`, `yes/no`, `on/off`) for project-owned boolean env flags.
- Legacy env flag names listed in `docs/progress/archived/20260116_env-bool-flags.md`.

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
