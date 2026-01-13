> Note: Before committing, replace all placeholder tokens (use `TBD` if unknown; use `None` if not applicable).

# progress_bar: Zsh progress bar utilities

| Status | Created | Updated |
| --- | --- | --- |
| DRAFT | 2026-01-14 | 2026-01-14 |

Links:

- PR: TBD
- Docs: TBD
- Glossary: `docs/templates/PROGRESS_GLOSSARY.md`

## Goal

- Provide a shared, low-noise progress bar utility for long-running Zsh commands.
- Support both determinate progress (`current/total`) and indeterminate progress (unknown duration).
- Ensure stability: no unexpected output in non-TTY / redirected contexts by default.

## Acceptance Criteria

- Determinate mode:
  - `progress_bar::init <id> --prefix <text> --total <n>` initializes a progress line.
  - `progress_bar::update <id> <current>` renders `"<prefix> [<bar>] <current>/<total>"` on a single line.
  - Default behavior only renders when stderr is a TTY; it must be silent in non-TTY contexts.
  - Rendering should be low-noise (only updates when the filled cell count changes, plus 0/total).
  - `progress_bar::finish <id>` forces a final update and prints a newline.
- Indeterminate mode:
  - `progress_bar::init_indeterminate <id> --prefix <text>` initializes a progress line.
  - `progress_bar::tick <id>` updates the same single-line progress bar (no `current/total`).
  - `progress_bar::stop <id>` clears the line and prints a newline.
  - Default behavior only renders when stderr is a TTY; it must be silent in non-TTY contexts.
- Compatibility:
  - Implementation must be Zsh-only and follow repo conventions (`emulate -L zsh`, `print -r --`, no `echo`).
  - Repo checks pass after implementation:
    - `./tools/check.zsh`
    - `./tools/audit-fzf-def-docblocks.zsh --check`

## Scope

- In-scope:
  - New first-party module: `scripts/progress-bar.zsh` (Zsh library functions).
  - Bootstrap preload shim (lazy-load) so cached CLI wrappers can use the progress utilities.
  - Unicode block bar by default with a reasonable ASCII fallback for non-UTF-8 locales.
  - Deterministic bar width defaults to `max(10, COLUMNS/4)` when not explicitly configured.
- Out-of-scope:
  - Wiring progress bars into existing commands (e.g. `codex-rate-limits`) in this planning PR.
  - Multi-progress (multiple concurrent bars) and interleaving-safe output for concurrent subprocess writes.
  - Rich terminal features (colors, cursor movement beyond carriage return, multi-line layouts).

## I/O Contract

### Input

- Function arguments:
  - IDs, prefixes, totals, current values, optional suffix text.
  - Optional control flags for width/head length and output FD (advanced/testing use).
- Environment:
  - Locale (`LC_ALL` / `LC_CTYPE` / `LANG`) for UTF-8 detection (unicode vs ASCII blocks).
  - `COLUMNS` when available (default width calculation).

### Output

- Side effect: progress line updates written to an output file descriptor (default: stderr).
- Rendering uses carriage return (`\r`) to rewrite a single line in place.
- Default rendering is disabled unless the output FD is a TTY.

### Intermediate Artifacts

- None (no files should be written by the progress bar library).

## Design / Decisions

### Rationale

- Keep the implementation in `scripts/progress-bar.zsh` to avoid bloating early bootstrap.
- Provide a thin lazy-load shim in `bootstrap/00-preload.zsh` because cached CLI wrappers bundle it.
- Default to TTY-only rendering to avoid breaking scripts that pipe or capture output.
- Mirror the existing Python reference behavior:
  - Width derived from terminal columns
  - Low-noise updates (cell-change based)
  - Left-padding overwrite to clear longer previous lines

### Risks / Uncertainties

- Unicode rendering may vary by terminal/font; locale-based UTF-8 detection is heuristic.
  - Mitigation: provide ASCII fallback; document how to force/override if needed.
- Carriage-return progress lines can interleave with other stderr output, producing messy logs.
  - Mitigation: keep progress output on stderr; keep updates low-frequency; ensure `stop/finish` ends cleanly.
- Global in-process state (tracking last line length and last filled) may leak across callers if IDs collide.
  - Mitigation: require unique IDs per command; ensure `finish/stop` cleans up state.
- Bundled wrappers include `bootstrap/00-preload.zsh`; incorrect lazy-load patterns can cause recursion bugs.
  - Mitigation: add a guard that detects whether the real implementation functions are loaded.

## Steps (Checklist)

Note: Any unchecked checkbox in Step 0–3 must include a Reason (inline `Reason: ...` or a nested `- Reason: ...`) before close-progress-pr can complete. Step 4 is excluded (post-merge / wrap-up).

- [x] Step 0: Align API and stability requirements
  - Work Items:
    - [x] Decide module placement: `scripts/progress-bar.zsh` + preload shim in `bootstrap/00-preload.zsh`.
    - [x] Decide default output semantics: render only when output FD is a TTY.
    - [x] Decide two modes (determinate + indeterminate) and the minimal public API.
    - [x] Define verification commands and expected outcomes (see Exit Criteria).
  - Artifacts:
    - `docs/progress/20260114_zsh-progress-bar.md` (this file)
    - Implementation draft (local-only): currently in `git stash` as "WIP progress bar implementation"
  - Exit Criteria:
    - [x] Requirements, scope, and acceptance criteria are aligned: progress PR review notes.
    - [x] Data flow and I/O contract are defined: see I/O Contract.
    - [x] Risks and mitigations are enumerated: see Risks / Uncertainties.
    - [x] Minimal reproducible verification commands are defined:
      - Syntax:
        - `zsh -n -- scripts/progress-bar.zsh`
        - `zsh -n -- bootstrap/00-preload.zsh`
      - Repo checks:
        - `./tools/check.zsh`
        - `./tools/audit-fzf-def-docblocks.zsh --check`
      - Non-TTY default silence (should produce no output):
        - `mkdir -p "$CODEX_HOME/out" && zsh -fc 'source bootstrap/00-preload.zsh; progress_bar::init pb --prefix Test --total 3; progress_bar::update pb 1; progress_bar::finish pb' 2> "$CODEX_HOME/out/progress.err" && wc -c "$CODEX_HOME/out/progress.err"`
      - Manual TTY demo (interactive):
        - `source bootstrap/00-preload.zsh`
        - `progress_bar::init_indeterminate pb --prefix 'Job'`
        - `for i in {1..40}; do progress_bar::tick pb --suffix \"tick=$i\"; sleep 0.05; done; progress_bar::stop pb`
- [ ] Step 1: Implement progress bar utilities (MVP) Reason: docs-only planning PR (no implementation changes)
  - Work Items:
    - [ ] Add `scripts/progress-bar.zsh` with determinate + indeterminate implementations.
    - [ ] Add preload shim in `bootstrap/00-preload.zsh` (lazy load; safe for bundled wrappers).
    - [ ] Ensure unicode + ASCII fallback behavior is stable across common locales.
  - Artifacts:
    - `scripts/progress-bar.zsh`
    - `bootstrap/00-preload.zsh`
  - Exit Criteria:
    - [ ] At least one happy path runs end-to-end (manual TTY):
      - Determinate: init/update/finish shows `current/total`
      - Indeterminate: init/tick/stop shows animated bar and terminates with a clean newline
    - [ ] Default behavior is silent in non-TTY contexts: see Step 0 commands.
    - [ ] Repo checks pass: `./tools/check.zsh`, `./tools/audit-fzf-def-docblocks.zsh --check`.
- [ ] Step 2: Integrate into long-running commands Reason: defer until MVP is reviewed
  - Work Items:
    - [ ] Identify first adopters (e.g. network-bound commands like `codex-rate-limits`, plugin fetch/update flows).
    - [ ] Add indeterminate progress wrappers where latency is unpredictable.
    - [ ] Add determinate progress where item counts are known (e.g. N files / N repos).
  - Artifacts:
    - `scripts/_features/codex/secrets/_codex-secret.zsh` (candidate integration point)
    - `bootstrap/plugin_fetcher.zsh` (candidate integration point)
  - Exit Criteria:
    - [ ] Integrations are gated to interactive TTY contexts and do not break piping/capture flows.
    - [ ] User-facing commands remain stable and do not emit extra output when non-interactive.
- [ ] Step 3: Validation / testing Reason: requires implementation PR(s)
  - Work Items:
    - [ ] Run repo checks and record results in the implementation PR.
    - [ ] Add minimal targeted tests if/where this repo’s test patterns support it.
    - [ ] Record manual TTY verification notes (progress rendering is hard to CI-assert).
  - Artifacts:
    - `./tools/check.zsh` output (pass/failed)
    - `./tools/audit-fzf-def-docblocks.zsh --check` output (pass/failed)
    - Manual evidence in PR (terminal recordings or notes)
  - Exit Criteria:
    - [ ] Validation commands executed with results recorded:
      - `./tools/check.zsh` (pass)
      - `./tools/audit-fzf-def-docblocks.zsh --check` (pass)
      - Any added tests (pass)
    - [ ] Real usage sampled (interactive terminals; at least one non-UTF8 locale test or forced ASCII mode).
- [ ] Step 4: Release / wrap-up
  - Work Items:
    - [ ] Add or update user docs for progress bar usage and integration patterns.
    - [ ] Update `CHANGELOG.md` for the feature release.
    - [ ] Mark this progress file DONE and archive it after the implementation PR is merged.
  - Artifacts:
    - `docs/cli/<tbd>.md` (if documentation is added)
    - `CHANGELOG.md`
    - `docs/progress/archived/20260114_zsh-progress-bar.md`
  - Exit Criteria:
    - [ ] Versioning and changes recorded: `CHANGELOG.md` (new content at the top).
    - [ ] Documentation completed and entry points updated (README / docs links).
    - [ ] Cleanup completed (set status to DONE, archive, update index).

## Modules

- `scripts/progress-bar.zsh`: determinate and indeterminate progress bar utilities (planned).
- `bootstrap/00-preload.zsh`: lazy-load shim for cached CLI wrappers (planned).
