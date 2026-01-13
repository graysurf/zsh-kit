# codex_starship_rate_limits: Starship line for Codex rate limits

| Status | Created | Updated |
| --- | --- | --- |
| DONE | 2026-01-03 | 2026-01-04 |

Links:

- PR: [graysurf/zsh-kit/pull/16](https://github.com/graysurf/zsh-kit/pull/16)
- Docs: `docs/cli/codex-starship.md`
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Addendum

### 2026-01-07

- `codex-starship`: append ` (stale)` when the cache is stale so Starship can tell the displayed usage is expired (cold cache still prints nothing).
- `CODEX_STARSHIP_STALE_SUFFIX`: customize/disable the stale suffix (default: ` (stale)`; set empty to disable).

## Goal

- Provide a fast, cacheable, machine-friendly `codex-starship` CLI that outputs the current Codex token identity and rate limit status for Starship.

## Acceptance Criteria

- `codex-starship` prints a single line suitable for Starship prompt rendering and exits `0`.
- Default output includes both windows: `<name> 5h:<pct> W:<pct> <weekly_reset_time>`.
- `codex-starship --no-5h` omits the 5h window output: `<name> W:<pct> <weekly_reset_time>`.
- TTL caching is enabled:
  - Default TTL: 5 minutes.
  - Configurable TTL: `--ttl 1m` and `--ttl 5m`.
  - Configurable via env: `CODEX_STARSHIP_TTL` (default: `5m`).
- Time formatting is supported:
  - Default: `MM-DD HH:MM` (UTC).
  - Configurable: `--time-format '<strftime>'`.
- Module enablement is supported:
  - Default disabled: `CODEX_STARSHIP_ENABLED=false`
  - When disabled: prints nothing and does not refresh.
- 5h visibility is supported:
  - Configurable via env: `CODEX_STARSHIP_SHOW_5H` (default: `true`).
- Failure / cache behavior (stale-while-revalidate):
  - If inputs are missing, parsing fails, or rate limits cannot be fetched: print nothing and exit `0` (module hidden).
  - If a cache exists: print it immediately (even if stale).
  - If cache is stale or missing: enqueue a background refresh (best effort).
  - `--refresh` forces a blocking refresh (updates cache).
- A cached CLI wrapper exists:
  - `scripts/_internal/wrappers.zsh` generates a `codex-starship` wrapper command for subshell contexts.

## Scope

- In-scope:
  - New first-party zsh CLI under `scripts/` (does not depend on `.private`).
  - Machine-readable parsing for: current token identity and rate limits (avoid parsing human UI output).
  - TTL cache implementation suitable for Starship prompt frequency.
  - Wrapper generation update: add `codex-starship` to `scripts/_internal/wrappers.zsh`.
- Out-of-scope:
  - Editing user-specific `starship.toml` directly (document the snippet instead).
  - Additional rate windows beyond `5h` and `Weekly` (unless already returned by the upstream command).

## I/O Contract

### Input

- `CODEX_AUTH_FILE` (default: `~/.config/codex-kit/auth.json`, fallback: `~/.codex/auth.json`) to determine the active token identity.
- `CODEX_SECRET_DIR` (optional; default: `$ZDOTDIR/scripts/_features/codex/secrets`) for friendly name resolution via profile file hash matching.
- Rate limits source: `https://chatgpt.com/backend-api/wham/usage` (via `curl` + bearer token from auth file).

### Output

- Single-line prompt text (no header), default:
  - `yourname 5h:68% W:20% 01-08 10:38`

### Intermediate Artifacts

- Cache file (keyed by token identity):
  - `$ZSH_CACHE_DIR/codex/starship-rate-limits/<token_key>.kv`

## Design / Decisions

### Rationale

- Starship runs commands frequently; caching prevents repeated network/API calls and reduces prompt latency.
- Machine-readable outputs reduce fragility versus parsing human-readable CLI formatting.
- Silent failure avoids breaking prompt rendering and matches the “hide module on failure” requirement.

### Risks / Uncertainties

- Upstream CLI output or auth file schema may change.
  - Mitigation: prefer upstream JSON (`wham/usage`) and keep Starship-facing output format stable.
- Rate limit calls may be slow or fail intermittently.
  - Mitigation: short TTL caching, bounded refresh, and reuse last-good cache while refreshing in the background.

## Steps (Checklist)

- [x] Step 0: Alignment / prerequisites
  - Work Items:
    - [x] Confirm output format and toggles (`--no-5h`, `--ttl`).
    - [x] Confirm name source: current active token identity from `~/.codex/auth.json`.
    - [x] Confirm failure behavior: print nothing, exit `0`.
  - Artifacts:
    - `docs/progress/20260103_codex_starship_rate_limits.md` (this file)
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned.
    - [x] Determine final cache path + keying strategy (token key format).
    - [x] Identify the best machine-readable upstream data source for rate limits.

- [x] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [x] Add `codex-starship` CLI skeleton with argument parsing and empty-safe output.
    - [x] Add wrapper generation entry in `scripts/_internal/wrappers.zsh`.
  - Exit Criteria:
    - [x] `codex-starship -h` shows usage and exits `0`.
    - [x] Wrapper generation succeeds in interactive shell startup.

- [x] Step 2: Expansion / integration
  - Work Items:
    - [x] Implement current token identity extraction (from auth.json).
    - [x] Implement rate limits fetching + parsing (prefer machine-readable).
    - [x] Implement TTL cache read/write with token-keyed cache entries.
    - [x] Implement stale-while-revalidate behavior (print cached output immediately; refresh in background).
    - [x] Add `--time-format` for weekly reset time formatting.
    - [x] Add `--refresh` for a blocking refresh (debug / warm cache).
    - [x] Add env toggles (`CODEX_STARSHIP_ENABLED`, `CODEX_STARSHIP_TTL`, `CODEX_STARSHIP_SHOW_5H`).
    - [x] Add Starship custom module config (`config/starship.toml`).
  - Exit Criteria:
    - [x] Starship-facing output matches the contract for both default and `--no-5h`.
    - [x] Cache reuse works and refresh respects TTL (SWR).

- [x] Step 3: Validation / testing
  - Work Items:
    - [x] Run repo checks and record results.
  - Artifacts:
    - `zsh -n -- scripts/codex-starship.zsh` (pass)
    - `zsh -n -- .zshrc` (pass)
    - `rg -n "\\[\\[.*\\]\\]" docs/progress -S` (pass; no output)
    - `./tools/audit-fzf-def-docblocks.zsh --check --stdout` (pass)
    - `codex-starship --ttl 5m` (pass; SWR output)
    - `codex-starship --refresh` (pass; updates cache)
    - `STARSHIP_CONFIG=config/starship.toml starship prompt` (pass; shows codex line)
    - `./tools/check.zsh` (pass)
    - `./tools/check.zsh --smoke` (pass)
  - Exit Criteria:
    - [x] `./tools/check.zsh` (pass)
    - [x] `./tools/check.zsh --smoke` (pass) if startup/wrapper behavior changes

- [x] Step 4: Release / wrap-up
  - Work Items:
    - [x] Open PR and keep this progress file updated with PR link.
    - [x] Set Status to DONE, move to `docs/progress/archived/`, update index.

## Modules

- `.zshrc`: wrapper generation sentinel includes `codex-starship`.
- `config/starship.toml`: Starship `custom` module configuration.
- `scripts/_internal/wrappers.zsh`: add `codex-starship` wrapper generation.
- `scripts/codex-starship.zsh`: `codex-starship` CLI + internal helpers.
- `docs/cli/codex-starship.md`: usage + Starship integration snippet.
