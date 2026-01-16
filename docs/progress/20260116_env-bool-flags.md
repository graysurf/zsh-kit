# env_bools: Boolean env flags standardization

| Status | Created | Updated |
| --- | --- | --- |
| IN PROGRESS | 2026-01-16 | 2026-01-16 |

Links:

- PR: https://github.com/graysurf/zsh-kit/pull/29
- Docs: TBD
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Goal

- Standardize project-owned boolean env flags to accept only `true|false` (case-insensitive).
- On invalid values: warn to stderr and treat as `false`.
- Unify naming: project-owned boolean flags end with `_ENABLED` (rename existing; no legacy aliases).
- Add a repo-local audit and wire it into `./tools/check.zsh` to prevent regressions (including `.private/`).

## Acceptance Criteria

- All env flags listed under Inventory are renamed/updated across code + docs, and `.private/priv-env.zsh` uses only
  `true|false` for them.
- Boolean parsing is consistent: only `true|false` are accepted; any other non-empty value warns to stderr and is treated
  as `false`.
- Repo validation passes after implementation:
  - `./tools/check.zsh --all` (pass)
  - `./tools/audit-env-bools.zsh --check` (pass)
- No tracked source/docs examples for Inventory flags use `=0` / `=1`.

## Scope

- In-scope:
  - Rename and standardize boolean env flags listed under Inventory across:
    - `.private/`
    - `.zshrc`
    - `bootstrap/`
    - `scripts/`
    - `tools/`
    - `config/`
    - `docs/`
  - Update `$CODEX_HOME` desktop notification scripts/docs for the renamed desktop notify env flags.
- Out-of-scope:
  - Backwards compatibility / legacy aliases for old env names or `0/1` values.
  - Third-party/upstream env vars (e.g. `NO_COLOR`, `NONINTERACTIVE`, `SHELL_SESSIONS_DISABLE`).
  - Non-boolean env vars (strings, integers, durations).
  - Vendored code under `plugins/`.

## I/O Contract

### Input

- User-configured env flags (see Inventory) set via shell startup (`~/.zshenv`, `.private/priv-env.zsh`, etc.).
- Repo source files that read/parse these env flags.
- `$CODEX_HOME` desktop-notify scripts (for `CODEX_DESKTOP_NOTIFY*`).

### Output

- Consistent boolean env contract for all Inventory flags:
  - Naming: `*_ENABLED`
  - Values: `true|false` only (case-insensitive)
  - Invalid value behavior: warn to stderr, treated as `false`
- Repo-local enforcement: `tools/audit-env-bools.zsh --check`.
- Updated docs/config examples to the new names/values.

### Intermediate Artifacts

- `docs/progress/20260116_env-bool-flags.md` (this file)
- `out/` artifacts produced by validation (e.g. Semgrep JSON from `./tools/check.zsh --semgrep`) (optional)

## Design / Decisions

### Rationale

- `*_ENABLED` is the single, uniform convention for boolean env flags (clear intent; easy to grep).
- Restricting to `true|false` avoids ambiguous `0/1` and reduces per-module parsing drift.
- A shared boolean parser + an audit script keeps behavior consistent and prevents regressions.

### Risks / Uncertainties

- Cross-repo coordination: `$CODEX_HOME` must be updated in lockstep for desktop notify env changes.
  - Mitigation: keep CODEX_HOME edits isolated and ship them as a separate PR (linked from implementation PR).
- Some existing flags are presence-based (set/unset) today; converting them to value-based booleans changes semantics.
  - Mitigation: explicitly list all affected flags in Inventory; no implicit refactors.

## Inventory

Proposed project rules (this repo):

- Boolean env flags: only `true` / `false` (case-insensitive).
- Invalid values: warn to stderr and treat as `false`.
- Naming: project-owned boolean flags end with `_ENABLED`.

| Env (current) | Env (new) | zsh-kit touchpoints | `$CODEX_HOME` touchpoints | Notes |
| --- | --- | --- | --- | --- |
| `CODEX_ALLOW_DANGEROUS` | `CODEX_ALLOW_DANGEROUS_ENABLED` | `.private/priv-env.zsh`<br>`scripts/_features/codex/codex-tools.zsh`<br>`docs/cli/codex-cli-helpers.md` | None | Rename; strict `true|false` only. |
| `CODEX_DESKTOP_NOTIFY` | `CODEX_DESKTOP_NOTIFY_ENABLED` | `.private/priv-env.zsh` | `skills/tools/devex/desktop-notify/SKILL.md`<br>`skills/tools/devex/desktop-notify/scripts/desktop-notify.sh`<br>`skills/tools/devex/desktop-notify/scripts/project-notify.sh` | Rename; switch from `0/1` examples/defaults to `true|false`. |
| `CODEX_DESKTOP_NOTIFY_HINTS` | `CODEX_DESKTOP_NOTIFY_HINTS_ENABLED` | `.private/priv-env.zsh` | `skills/tools/devex/desktop-notify/SKILL.md`<br>`skills/tools/devex/desktop-notify/scripts/desktop-notify.sh`<br>`skills/tools/devex/desktop-notify/scripts/project-notify.sh` | Rename; switch from `0/1` examples/defaults to `true|false`. |
| `CODEX_AUTO_REFRESH_ENABLED` | (unchanged) | `.private/priv-env.zsh`<br>`scripts/_features/codex/codex-auto-refresh.zsh` | None | Keep name; tighten parser to `true|false` only. |
| `CODEX_RATE_LIMITS_DEFAULT_ALL` | `CODEX_RATE_LIMITS_DEFAULT_ALL_ENABLED` | `.private/priv-env.zsh`<br>`scripts/_features/codex/secrets/_codex-secret.zsh` | None | Rename; tighten parser to `true|false` only. |
| `CODEX_SYNC_AUTH_ON_CHANGE_ENABLED` | (unchanged) | `scripts/_features/codex/secrets/_codex-secret.zsh` | None | Keep name; tighten parser to `true|false` only. |
| `CODEX_STARSHIP_ENABLED` | (unchanged) | `.private/priv-env.zsh`<br>`scripts/_features/codex/codex-starship.zsh`<br>`config/starship.toml`<br>`docs/cli/codex-starship.md` | None | Keep name; remove `1|yes|on` support everywhere. |
| `CODEX_STARSHIP_SHOW_5H` | `CODEX_STARSHIP_SHOW_5H_ENABLED` | `.private/priv-env.zsh`<br>`scripts/_features/codex/codex-starship.zsh`<br>`docs/cli/codex-starship.md`<br>`docs/progress/archived/20260103_codex_starship_rate_limits.md` | None | Rename; strict `true|false` only. |
| `CODEX_STARSHIP_SHOW_FALLBACK_NAME` | `CODEX_STARSHIP_SHOW_FALLBACK_NAME_ENABLED` | `.private/priv-env.zsh`<br>`scripts/_features/codex/codex-starship.zsh`<br>`docs/cli/codex-starship.md` | None | Rename; strict `true|false` only. |
| `ZSH_BOOT_WEATHER` | `ZSH_BOOT_WEATHER_ENABLED` | `.zshrc`<br>`docs/guides/login-banner.md`<br>`docs/guides/startup-files.md` | None | Rename; default stays `true`. |
| `ZSH_BOOT_QUOTE` | `ZSH_BOOT_QUOTE_ENABLED` | `.zshrc`<br>`docs/guides/startup-files.md` | None | Rename; default stays `true`. |
| `FZF_DEF_DOC_CACHE_ENABLE` | `FZF_DEF_DOC_CACHE_ENABLED` | `scripts/env.zsh`<br>`scripts/fzf-tools.zsh` | None | Rename; strict `true|false` only. |
| `PLUGIN_FETCH_DRY_RUN` | `PLUGIN_FETCH_DRY_RUN_ENABLED` | `bootstrap/plugin_fetcher.zsh`<br>`docs/guides/plugin-system.md`<br>`tools/check.zsh` | None | Rename; strict `true|false` only. |
| `PLUGIN_FETCH_FORCE` | `PLUGIN_FETCH_FORCE_ENABLED` | `bootstrap/plugin_fetcher.zsh`<br>`docs/guides/plugin-system.md` | None | Rename; strict `true|false` only. |
| `DRY_RUN` | `ZSH_INSTALL_TOOLS_DRY_RUN_ENABLED` | `bootstrap/install-tools.zsh` | None | Rename; avoid generic env name collisions; strict `true|false` only. |
| `QUIET` | `ZSH_INSTALL_TOOLS_QUIET_ENABLED` | `bootstrap/install-tools.zsh` | None | Rename; strict `true|false` only. |
| `INCLUDE_OPTIONAL` | `ZSH_INSTALL_TOOLS_INCLUDE_OPTIONAL_ENABLED` | `bootstrap/install-tools.zsh` | None | Rename; strict `true|false` only. |
| `RDP_ASSUME_YES` | `RDP_ASSUME_YES_ENABLED` | `scripts/chrome-devtools-rdp.zsh` | None | Rename; remove `(1\|y\|yes\|true)` support; strict `true|false` only. |
| `RDP_REFRESH_PROFILE` | `RDP_REFRESH_PROFILE_ENABLED` | `scripts/chrome-devtools-rdp.zsh` | None | Rename; strict `true|false` only. |
| `RDP_DEBUG` | `RDP_DEBUG_ENABLED` | `scripts/chrome-devtools-rdp.zsh` | None | Rename; strict `true|false` only. |
| `RDP_USE_ISOLATED_PROFILE` | `RDP_USE_ISOLATED_PROFILE_ENABLED` | `scripts/chrome-devtools-rdp.zsh` | None | Rename; strict `true|false` only. |
| `SHELL_UTILS_NO_BUILTIN_OVERRIDES` | `SHELL_UTILS_BUILTIN_OVERRIDES_ENABLED` | `scripts/builtin-overrides.zsh` | None | Convert from presence-based opt-out to value-based opt-in/out (default: `true`). |

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).

- [x] Step 0: Alignment / prerequisites
  - Work Items:
    - [x] Review and confirm the Inventory table (env list + renames + touched files).
    - [x] Confirm explicit exclusions for upstream env vars (e.g. `SHELL_SESSIONS_DISABLE`, `NONINTERACTIVE`).
    - [x] Confirm whether any additional boolean env flags should be added to Inventory before implementation starts.
  - Artifacts:
    - `docs/progress/<YYYYMMDD>_<feature_slug>.md` (this file)
    - Inventory table (in this file)
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned.
    - [x] Data flow and I/O contract are defined.
    - [x] Risks and rollout plan are defined (including cross-repo coordination for `$CODEX_HOME`).
    - [x] Verification commands are defined:
      - `./tools/check.zsh --all`
      - `./tools/audit-env-bools.zsh --check`
- [x] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [x] Introduce a shared boolean env parser helper (single source of truth).
    - [x] Apply env renames + strict parsing across all Inventory flags in this repo.
    - [x] Update `.private/priv-env.zsh` to the new names and `true|false` values.
    - [x] Update `$CODEX_HOME` desktop-notify scripts/docs for `CODEX_DESKTOP_NOTIFY*_ENABLED`.
  - Artifacts:
    - Updated sources under `.private/`, `bootstrap/`, `scripts/`, `tools/`, `config/`, `docs/`
    - Updated `$CODEX_HOME/skills/tools/devex/desktop-notify/` sources
  - Exit Criteria:
    - [x] `./tools/check.zsh --all` passes (record output in PR Testing).
    - [x] `.private/priv-env.zsh` uses only the new names and `true|false` for Inventory flags.
    - [x] Desktop notifications still work with the new env flags (smoke via `$CODEX_HOME/.../project-notify.sh`).
- [x] Step 2: Expansion / integration
  - Work Items:
    - [x] Add `tools/audit-env-bools.zsh --check` and integrate into `./tools/check.zsh --all`.
    - [x] Remove remaining `0/1` examples for Inventory flags in docs/config.
  - Artifacts:
    - `tools/audit-env-bools.zsh`
    - Updated docs under `docs/` and config under `config/`
  - Exit Criteria:
    - [x] `./tools/audit-env-bools.zsh --check` passes.
    - [x] No Inventory flags remain with legacy names or `0/1` examples in tracked docs/config.
- [x] Step 3: Validation / testing
  - Work Items:
    - [x] Run and record full repo validation (`./tools/check.zsh --all`).
    - [x] Add/adjust targeted smoke commands for key modules (Codex feature, plugin fetcher, chrome RDP helper).
  - Artifacts:
    - PR `Testing` notes (pass/failed/skipped per command)
    - Any logs under `out/` (when produced)
  - Exit Criteria:
    - [x] Validation and test commands executed with results recorded (pass/failed/skipped).
    - [x] Smoke run with representative configuration (including `.private/priv-env.zsh`).
    - [x] Evidence exists (logs/outputs/commands) in PR description or `out/`.
    - Results:
      - `./tools/audit-env-bools.zsh --check`: pass
      - `./tools/check.zsh --all`: pass (Semgrep reports 4 findings; JSON: `out/semgrep/semgrep-zsh-20260116-101642.json`)
      - `./tools/audit-fzf-def-docblocks.zsh --check`: pass (report: `cache/fzf-def-docblocks-audit.txt`)
      - `$CODEX_HOME/scripts/check.sh --all`: pass (118 tests; Semgrep JSON: `$CODEX_HOME/out/semgrep/semgrep-codex-kit-20260116-101515.json`)
- [ ] Step 4: Release / wrap-up
  - Work Items:
    - [ ] Update changelog and entry points if needed (`CHANGELOG.md`, `README.md`, docs index links).
    - [ ] Remove any temporary migration notes; set progress Status to `DONE` and archive.
  - Artifacts:
    - `CHANGELOG.md` (if updated)
    - Archived progress file under `docs/progress/archived/`
  - Exit Criteria:
    - [ ] Changes recorded and docs entry points updated.
    - [ ] Cleanup completed (remove temporary notes/files; set Status to `DONE`; update index).

## Modules

- `tools/audit-env-bools.zsh`: enforce boolean env conventions (`*_ENABLED`, `true|false` only).
- `bootstrap/00-preload.zsh`: shared `true|false` env parsing with warn+false on invalid (`zsh_env::is_true`).
- `bootstrap/`: adopt renamed `*_ENABLED` env flags (plugin fetcher, install-tools).
- `scripts/_features/codex/`: adopt renamed `*_ENABLED` env flags and strict parsing.
- `scripts/chrome-devtools-rdp.zsh`: adopt renamed `*_ENABLED` env flags and strict parsing.
