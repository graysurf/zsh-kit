# codex_starship_rate_limits: Starship line for Codex rate limits

| Status | Created | Updated |
| --- | --- | --- |
| IN PROGRESS | 2026-01-03 | 2026-01-04 |

Links:

- PR: TBD
- PR: [graysurf/zsh-kit/pull/16](https://github.com/graysurf/zsh-kit/pull/16)
- Docs: TBD (Starship config snippet + usage)
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Goal

- Provide a fast, cacheable, machine-friendly `codex-starship` CLI that outputs the current Codex token identity and rate limit status for Starship.

## Acceptance Criteria

- `codex-starship` prints a single line suitable for Starship prompt rendering and exits `0`.
- Default output includes both windows: `<name> 5h:<pct> W:<pct> <weekly_expire_time>`.
- `codex-starship --no-5h` omits the 5h window output: `<name> W:<pct> <weekly_expire_time>`.
- TTL caching is enabled:
  - Default TTL: 5 minutes.
  - Configurable TTL: `--ttl 1m` and `--ttl 5m`.
- Failure behavior:
  - If inputs are missing, parsing fails, or rate limits cannot be fetched: print nothing and exit `0` (module hidden).
  - If a non-expired cache exists: reuse cached output.
- A cached CLI wrapper exists:
  - `scripts/_internal/wrappers.zsh` generates a `codex-starship` wrapper command for subshell contexts.

## Scope

- In-scope:
  - New first-party zsh library + CLI under `scripts/` (no duplication of `.private` functions).
  - Machine-readable helpers for: current token identity and rate limits (avoid parsing human UI output).
  - TTL cache implementation suitable for Starship prompt frequency.
  - Wrapper generation update: add `codex-starship` to `scripts/_internal/wrappers.zsh`.
- Out-of-scope:
  - Editing user-specific `starship.toml` directly (document the snippet instead).
  - Additional rate windows beyond `5h` and `Weekly` (unless already returned by the upstream command).

## I/O Contract

### Input

- `~/.codex/auth.json` (or the repo’s configured auth path) to determine the active token identity.
- Codex rate limit source used by the existing `codex-rate-limits` command.

### Output

- Single-line prompt text (no header), default:
  - `terry 5h:68% W:20% 2026-01-08T10:38:46Z`

### Intermediate Artifacts

- Cache file (keyed by token identity):
  - `~/.cache/codex/starship-rate-limits/<token_key>.txt` (exact path TBD; must not be in `/tmp`)

## Design / Decisions

### Rationale

- Starship runs commands frequently; caching prevents repeated network/API calls and reduces prompt latency.
- Machine-readable outputs reduce fragility versus parsing human-readable CLI formatting.
- Silent failure avoids breaking prompt rendering and matches the “hide module on failure” requirement.

### Risks / Uncertainties

- Upstream CLI output or auth file schema may change.
  - Mitigation: add `--json/--tsv` style helpers and keep Starship-facing output format stable.
- Rate limit calls may be slow or fail intermittently.
  - Mitigation: short TTL caching, bounded refresh, and reuse last-good cache when not expired.

## Steps (Checklist)

- [ ] Step 0: Alignment / prerequisites
  - Work Items:
    - [x] Confirm output format and toggles (`--no-5h`, `--ttl`).
    - [x] Confirm name source: current active token identity from `~/.codex/auth.json`.
    - [x] Confirm failure behavior: print nothing, exit `0`.
  - Artifacts:
    - `docs/progress/20260103_codex_starship_rate_limits.md` (this file)
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned.
    - [ ] Determine final cache path + keying strategy (token key format).
    - [ ] Identify the best machine-readable upstream data source for rate limits.

- [ ] Step 1: Minimum viable output (MVP)
  - Work Items:
    - [ ] Add `codex-starship` CLI skeleton with argument parsing and empty-safe output.
    - [ ] Add wrapper generation entry in `scripts/_internal/wrappers.zsh`.
  - Exit Criteria:
    - [ ] `codex-starship` runs successfully and prints nothing by default (until data sources are wired).
    - [ ] Wrapper generation succeeds in interactive shell startup.

- [ ] Step 2: Expansion / integration
  - Work Items:
    - [ ] Implement current token identity extraction (from `~/.codex/auth.json`).
    - [ ] Implement rate limits fetching + parsing (prefer machine-readable).
    - [ ] Implement TTL cache read/write with token-keyed cache entries.
  - Exit Criteria:
    - [ ] Starship-facing output matches the contract for both default and `--no-5h`.
    - [ ] Cache reuse works and refresh respects TTL.

- [ ] Step 3: Validation / testing
  - Work Items:
    - [ ] Run repo checks and record results.
  - Exit Criteria:
    - [ ] `./tools/check.zsh` (pass)
    - [ ] `./tools/check.zsh --smoke` (pass) if startup/wrapper behavior changes

- [ ] Step 4: Release / wrap-up
  - Work Items:
    - [ ] Open PR and keep this progress file updated with PR link.
    - [ ] When merged, set Status to DONE, move to `docs/progress/archived/`, update index.

## Modules

- `scripts/_internal/wrappers.zsh`: add `codex-starship` wrapper generation.
- `scripts/` (new): `codex-starship` library + CLI (design TBD; will follow repo zsh conventions).
