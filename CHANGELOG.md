# Changelog
<!-- markdownlint-disable-file MD024 -->

All notable changes to this project will be documented in this file.

## v2.2.1 - 2026-06-04

### Changed

- Publish the current Zsh runtime setup surface for Docker/opencode consumers after the nils-cli
  `zsh-kit --write-zshenv` bootstrap update. The setup hook remains the owner of shell-specific
  feature wiring while nils-cli owns clone/update/bootstrap dispatch.

## v2.2.0 - 2026-06-03

### Changed

- `git-magic` / `git` open-variant aliases (`gpo`, `gcpo`, `gcapo`, ...) now call the native
  `git-cli open commit` (nils-cli) instead of the retired `git-open` wrapper.
- Login-banner weather and the `weather` helper prefer `weather-cli today --city $ZSH_WEATHER_CITY`
  (nils-cli) and fall back to wttr.in when `weather-cli` or `ZSH_WEATHER_CITY` is unavailable.
- The weather-cli banner renders a compact one-liner via `zsh_weather::format_today_json`
  (`🌦  Taipei  25~35°C  ☔ 59%  Drizzle`): WMO-code-mapped emoji, rounded temps, no
  source/freshness meta, ☔ segment omitted at 0% rain; falls back to weather-cli's human
  output when jq is unavailable.
- `open-changed-files` is now a shell function (alias: `ocf`) in `scripts/shell-tools.zsh`
  delegating to `tools/open-changed-files.zsh` (replaces the cached wrapper binary).
- `docs/README.md` index rewritten around the current module set; `fzf-def-docs.md` renamed its
  subject from `fzf-tools` to `fzf-cli`.

### Removed

- Dead utility chain with no remaining consumers: `scripts/progress-bar.zsh`,
  `scripts/async-pool.zsh`, `scripts/ansi-utils.zsh` (plus `00-preload.zsh` shims, tests, and the
  progress-bar guide).
- `scripts/chrome-devtools-rdp.zsh` (unused Chrome remote-debugging helpers).
- The cached CLI wrapper/bundler system: `scripts/_internal/wrappers.zsh`,
  `wrappers.bundle-prelude.zsh`, `tools/bundle-wrapper.zsh`, the `.zshrc` wrapper PATH block, and
  the stale `cache/wrappers/bin` runtime artifacts it left behind.
- The unused `scripts/_internal/paths.zsh` compat wrapper.
- Stale references from the previous archive pass: the `git/git-tools.zsh` bootstrap entry, the
  dead `git-open` fzf-tab zstyle block in `completion.zsh`, duplicated legacy CLI docs under
  `docs/cli/` (already preserved in `archive/legacy-zsh-cli-tools/`), and orphan screenshots
  (moved next to the archived docs).

## v2.1.4 - 2026-02-04

### Changed

- Archived legacy Zsh implementations for `fzf-tools`, `git-scope`, and `codex-tools` under `archive/legacy-zsh-cli-tools/`.
- Cached wrapper generation no longer emits wrappers for those tools to avoid shadowing native binaries.
- Added lightweight alias shims (`ft`, `gs`, `cx`, etc.) that target the native binaries.

### Removed

- Repo-shipped completion scripts for the archived tools (moved to `archive/legacy-zsh-cli-tools/`).
- Legacy tests for the archived tools (moved to `archive/legacy-zsh-cli-tools/`).

## v2.1.3 - 2026-01-28

### Added

- `git-scope` can print staged changes with index-aware output.
- `git-open` can normalize scp-style remote URLs without a user.
- Linux tool list now includes `libnotify`.

### Changed

- `git-scope` tracked file filtering refactored to use arrays for improved performance.
- CI check workflow extended for broader coverage.

### Fixed

- Hardened plugin id parsing to reject unsafe plugin ids.
- `git-scope` supports `./` prefixes in tracked filters and adds a `mktemp` fallback.
- `git-tools` avoids grep warnings in `gdbs`.
- `bundle-wrapper` syncs from codex-kit and adds a docblock for the sources parser.
- Git scope lookups treat empty results as success.
- `progress-bar` prefers an explicit locale environment order.
- `git-open` trims trailing slashes in normalized remotes.
- `git-lock list` guards timestamp parsing to avoid `date -d` on macOS.

## v2.1.2 - 2026-01-22

### Added

- `codex-workspace start` / `codex-workspace stop` for managing existing workspaces.
- `codex-workspace rsync` command for syncing host workspaces into containers.
- `git-tools` shorthand aliases (`gt*`) and refreshed `git-tree` aliases.

### Changed

- `codex-workspace` delegates `ls`/`rm` and tunnel management to the codex-kit workspace launcher.
- Codex secrets module renamed to `codex-secret.zsh` and alias wiring centralized.
- Starship container module config simplified.

### Fixed

- `codex-workspace` no longer persists `GH_TOKEN` into workspace container env during setup.
- `git-open` remote normalization handles non-https remotes and strips userinfo.
- `chrome-devtools-rdp` profile pruning and wait-for-exit logic.
- Plugin fetcher guards invalid plugin entries.
- `open-changed-files` respects code disable in dry-run.
- `fzf-history` preserves backslash-escaped spaces.
- Test harness no longer auto-opens VS Code during runs.
- Safer temp directory creation in tooling.

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
- Legacy env flag names tracked in historical migration notes.

## v1.0.3 - 2026-01-16

### Added

- Semgrep integration with repo-local rules (`.semgrep.yaml`) via
  `tools/semgrep-scan.zsh` and `tools/check.zsh --semgrep` (writes JSON output under `out/semgrep/`).
- Raw prompt mode for `codex-tools` and `opencode-tools` (use `--` or `prompt` to force).
- `-a|--auto-stage` option for `codex-tools commit-with-scope` and `opencode-tools commit-with-scope` to run `semantic-commit-autostage`.

### Changed

- Hardened bootstrap/tooling by removing `eval` (wrapper bundler, plugin loader, and `install-tools.zsh`) and safely parsing
  `plugins.list` `KEY=VALUE` extras (including quoted values).
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
