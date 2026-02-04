# Plan: Archive legacy zsh fzf-tools, git-scope, codex-tools

## Overview
This plan archives the legacy Zsh implementations (scripts + completions + docs + tests) for `fzf-tools`, `git-scope`, and `codex-tools` into a dedicated `archive/` subtree so the code remains browsable but is no longer maintained. The active command implementations are expected to come from native binaries (Rust) installed outside this repo; this repo will stop generating cached wrapper scripts that shadow those binaries. Where needed, we keep minimal shell UX glue (aliases and feature toggles) while removing the legacy runtime code paths. The rollout emphasizes “no shadowing”, link-safe archived docs, and repo checks staying green.

## Scope
- In scope: define an archive layout/policy; move the legacy files (scripts/docs/completions/tests) for the three tools into `archive/`; stop generating cached wrappers for these tools; update feature init/docs/README to reflect the change; ensure `./tools/check.zsh` and `./tests/run.zsh` still pass.
- Out of scope: implementing or refactoring the Rust binaries themselves; publishing/maintaining Homebrew formulae/taps; adding new features unrelated to archiving/migration; changing unrelated Git tooling behavior.

## Assumptions (if any)
1. Native binaries named `fzf-tools`, `git-scope`, and `codex-tools` exist (or will exist before rollout) on `PATH` in real interactive usage (e.g., via Homebrew or `cargo install`).
2. It is acceptable for this repo to stop “owning” these commands; after migration, this repo provides (at most) light shell integration and documentation pointers.
3. It is acceptable to archive (remove from active test runs) the legacy tests that exercised the Zsh implementations for these tools.

## Sprint 1: Inventory & archival design
**Goal**: Identify every touchpoint for the three tools and lock in a concrete archive layout + migration strategy (including wrapper shadowing and doc/link strategy).
**Demo/Validation**:
- Command(s): `rg -n "\\bfzf-tools\\b|\\bgit-scope\\b|\\bcodex-tools\\b" -S .`
- Verify: Produce a final file move list and confirm no remaining runtime dependencies on legacy helper functions once wrappers are removed.

### Task 1.1: Inventory touchpoints and dependencies
- **Location**:
  - `scripts/_internal/wrappers.zsh`
  - `.zshrc`
  - `scripts/fzf-tools.zsh`
  - `scripts/git/git-scope.zsh`
  - `scripts/_features/codex/codex-tools.zsh`
  - `scripts/_completion/_fzf-tools`
  - `scripts/_completion/_git-scope`
  - `scripts/_features/codex/_completion/_codex-tools`
  - `docs/cli/fzf-tools.md`
  - `docs/cli/git-scope.md`
  - `docs/cli/codex-cli-helpers.md`
  - `tests/fzf-history-backslash.test.zsh`
  - `tests/git-scope-tracked-prefix.test.zsh`
  - `tests/git-scope-print-sources.test.zsh`
  - `tests/codex-tools-groups.test.zsh`
  - `tests/codex-tools-rate-limits-async.test.zsh`
- **Description**: Enumerate all files, wrappers, feature init paths, docs links, and tests that reference these tools; identify “shadowing” points (cached wrappers in `$ZSH_CACHE_DIR/wrappers/bin`) and call-sites that must keep working with native binaries.
- **Dependencies**:
  - none
- **Complexity**: 3
- **Acceptance criteria**:
  - A single canonical “move list” exists for the legacy files to archive (scripts, completions, docs, tests).
  - All remaining call-sites are classified as either “must keep working with native binary” or “can be archived with the tool”.
- **Validation**:
  - `rg -n "\\bfzf-tools\\b|\\bgit-scope\\b|\\bcodex-tools\\b" -S scripts docs tests .zshrc`

### Task 1.2: Define archive layout and “frozen” policy
- **Location**:
  - `archive/README.md`
  - `archive/legacy-zsh-cli-tools/README.md`
- **Description**: Create a top-level `archive/` folder for long-term retention and a dedicated subtree `archive/legacy-zsh-cli-tools/` that mirrors the prior paths (`docs/`, `scripts/`, `tests/`). Document the rules: archived code is view-only, not sourced by default, and only receives link-fix changes (no feature work).
- **Dependencies**:
  - Task 1.1
- **Complexity**: 4
- **Acceptance criteria**:
  - Archive folders and READMEs clearly state purpose, scope, and the replacement source (native binaries).
  - Archive subtree mirrors prior paths to make browsing/diffing straightforward.
- **Validation**:
  - `test -f archive/README.md && test -f archive/legacy-zsh-cli-tools/README.md`

### Task 1.3: Confirm native binaries exist and are not shadowed
- **Location**:
  - `.zshrc`
  - `scripts/_internal/wrappers.zsh`
- **Description**: Verify that `fzf-tools`, `git-scope`, and `codex-tools` resolve to native binaries (not cached wrappers). Decide whether to (a) remove wrapper generation for these names, (b) add explicit cleanup for stale wrappers, and (c) keep/restore short aliases (`ft`, `gs`, `cx`) without reintroducing the legacy implementations.
- **Dependencies**:
  - Task 1.1
- **Complexity**: 5
- **Acceptance criteria**:
  - Clear decision recorded: wrappers for these tool names will no longer be generated; stale wrapper executables will be removed during migration.
  - Alias policy decided: keep or drop `ft`/`gs`/`cx` shortcuts after migration.
- **Validation**:
  - `command -v fzf-tools || true; command -v git-scope || true; command -v codex-tools || true`
  - `ls -la "${ZSH_CACHE_DIR:-$PWD/cache}/wrappers/bin" | rg -n "^(.* )?(fzf-tools|git-scope|codex-tools)$" || true`

## Sprint 2: Archive fzf-tools (legacy Zsh) and remove wrapper shadowing
**Goal**: Move the legacy `fzf-tools` Zsh implementation, completion, docs, and tests into the archive; ensure interactive shells use the native `fzf-tools` binary (if installed) without a cached wrapper shadowing it.
**Demo/Validation**:
- Command(s): `zsh -lic 'command -v fzf-tools && alias ft 2>/dev/null || true'`
- Verify: `fzf-tools` resolves outside `$ZSH_CACHE_DIR/wrappers/bin`, and repo checks still pass.

### Task 2.1: Move legacy fzf-tools files into archive
- **Location**:
  - `scripts/fzf-tools.zsh`
  - `scripts/_completion/_fzf-tools`
  - `docs/cli/fzf-tools.md`
  - `tests/fzf-history-backslash.test.zsh`
  - `archive/legacy-zsh-cli-tools/scripts/fzf-tools.zsh`
  - `archive/legacy-zsh-cli-tools/scripts/_completion/_fzf-tools`
  - `archive/legacy-zsh-cli-tools/docs/cli/fzf-tools.md`
  - `archive/legacy-zsh-cli-tools/tests/fzf-history-backslash.test.zsh`
- **Description**: Use `git mv` to relocate the legacy implementation, completion, user docs, and legacy tests into the archive subtree. Keep the archived doc browsable by ensuring image links continue to resolve (either by adjusting relative links or by documenting required asset paths).
- **Dependencies**:
  - Task 1.2
  - Task 1.3
- **Complexity**: 6
- **Acceptance criteria**:
  - Legacy `fzf-tools` code no longer exists under active `scripts/` or `scripts/_completion/`.
  - Archived docs render with working image links when viewed from the new location.
  - Legacy tests are no longer executed by `./tests/run.zsh`.
- **Validation**:
  - `test ! -f scripts/fzf-tools.zsh && test -f archive/legacy-zsh-cli-tools/scripts/fzf-tools.zsh`
  - `test ! -f scripts/_completion/_fzf-tools && test -f archive/legacy-zsh-cli-tools/scripts/_completion/_fzf-tools`
  - `test ! -f tests/fzf-history-backslash.test.zsh && test -f archive/legacy-zsh-cli-tools/tests/fzf-history-backslash.test.zsh`

### Task 2.2: Remove cached wrapper generation for fzf-tools and clean stale wrappers
- **Location**:
  - `scripts/_internal/wrappers.zsh`
  - `cache/wrappers/bin/fzf-tools`
- **Description**: Update wrapper generation so `fzf-tools` is no longer written under `$ZSH_CACHE_DIR/wrappers/bin`. Add an explicit cleanup step to remove any existing stale wrapper executable so it cannot shadow the native binary.
- **Dependencies**:
  - Task 2.1
- **Complexity**: 5
- **Acceptance criteria**:
  - Running `_wrappers::ensure_all` does not recreate `$ZSH_CACHE_DIR/wrappers/bin/fzf-tools`.
  - `$ZSH_CACHE_DIR/wrappers/bin/fzf-tools` is absent after cleanup.
- **Validation**:
  - `ZDOTDIR="$PWD" ZSH_CACHE_DIR="$PWD/cache" zsh -lc 'source "$ZDOTDIR/scripts/_internal/wrappers.zsh" && _wrappers::ensure_all >/dev/null 2>&1 || true; test ! -f "$ZSH_CACHE_DIR/wrappers/bin/fzf-tools"'`

### Task 2.3: Restore (optional) minimal aliases for fzf-tools without legacy code
- **Location**:
  - `scripts/aliases.fzf-tools.zsh`
- **Description**: If you want to keep the existing UX, reintroduce `ft`, `fgs`, `gg`, `fgc`, `ff`, `fv`, `fp` aliases in a small dedicated script that does not implement `fzf-tools` itself (it only points to the external binary commands).
- **Dependencies**:
  - Task 1.3
  - Task 2.2
- **Complexity**: 3
- **Acceptance criteria**:
  - `alias ft` exists in interactive shells and expands to `fzf-tools`.
  - No `fzf-tools()` function is defined by this repo.
- **Validation**:
  - `zsh -lic 'alias ft >/dev/null 2>&1 && ! typeset -f fzf-tools >/dev/null 2>&1'`

## Sprint 3: Archive git-scope (legacy Zsh) and validate downstream users
**Goal**: Archive the legacy Zsh `git-scope` implementation and completion, stop wrapper shadowing, and ensure downstream scripts that call `git-scope` (e.g., git commit context helpers) still work with the native binary.
**Demo/Validation**:
- Command(s): `zsh -lic 'command -v git-scope && git-scope help | head -n 5 || true'`
- Verify: `git-scope` resolves outside `$ZSH_CACHE_DIR/wrappers/bin`, and `git-commit-context` still runs when staged changes exist.

### Task 3.1: Move legacy git-scope files into archive
- **Location**:
  - `scripts/git/git-scope.zsh`
  - `scripts/_completion/_git-scope`
  - `docs/cli/git-scope.md`
  - `tests/git-scope-tracked-prefix.test.zsh`
  - `tests/git-scope-print-sources.test.zsh`
  - `archive/legacy-zsh-cli-tools/scripts/git/git-scope.zsh`
  - `archive/legacy-zsh-cli-tools/scripts/_completion/_git-scope`
  - `archive/legacy-zsh-cli-tools/docs/cli/git-scope.md`
  - `archive/legacy-zsh-cli-tools/tests/git-scope-tracked-prefix.test.zsh`
  - `archive/legacy-zsh-cli-tools/tests/git-scope-print-sources.test.zsh`
- **Description**: `git mv` the legacy implementation, completion, docs, and tests into the archive subtree. Ensure the archive keeps the original directory structure (`scripts/git/...`) for readability.
- **Dependencies**:
  - Task 1.2
  - Task 1.3
- **Complexity**: 5
- **Acceptance criteria**:
  - Legacy `git-scope` code is removed from active `scripts/` and `scripts/_completion/`.
  - Legacy `git-scope` tests are no longer executed by `./tests/run.zsh`.
- **Validation**:
  - `test ! -f scripts/git/git-scope.zsh && test -f archive/legacy-zsh-cli-tools/scripts/git/git-scope.zsh`
  - `test ! -f scripts/_completion/_git-scope && test -f archive/legacy-zsh-cli-tools/scripts/_completion/_git-scope`

### Task 3.2: Remove cached wrapper generation for git-scope and adjust dependent wrapper manifests
- **Location**:
  - `scripts/_internal/wrappers.zsh`
  - `cache/wrappers/bin/git-scope`
- **Description**: Stop generating the `git-scope` cached wrapper and remove the stale wrapper file. Update wrapper manifests that previously sourced `git/git-scope.zsh` (notably the `git-tools` wrapper sources list and any other wrapper that included it) so wrapper generation does not fail after archiving.
- **Dependencies**:
  - Task 3.1
- **Complexity**: 6
- **Acceptance criteria**:
  - Wrapper generation completes without referencing `scripts/git/git-scope.zsh`.
  - `$ZSH_CACHE_DIR/wrappers/bin/git-scope` is absent and does not get recreated.
- **Validation**:
  - `ZDOTDIR="$PWD" ZSH_CACHE_DIR="$PWD/cache" zsh -lc 'source "$ZDOTDIR/scripts/_internal/wrappers.zsh" && _wrappers::ensure_all >/dev/null 2>&1 || true; test ! -f "$ZSH_CACHE_DIR/wrappers/bin/git-scope"'`

### Task 3.3: Preserve (optional) minimal aliases for git-scope without legacy code
- **Location**:
  - `scripts/git/aliases.git-scope.zsh`
- **Description**: If you want to keep existing shorthands, reintroduce `gs`, `gsc`, `gst` as aliases pointing to the external `git-scope` binary.
- **Dependencies**:
  - Task 1.3
  - Task 3.2
- **Complexity**: 2
- **Acceptance criteria**:
  - `alias gs` exists and expands to `git-scope`.
  - No `git-scope()` function is defined by this repo.
- **Validation**:
  - `zsh -lic 'alias gs >/dev/null 2>&1 && ! typeset -f git-scope >/dev/null 2>&1'`

### Task 3.4: Validate downstream scripts that use git-scope output
- **Location**:
  - `scripts/git/tools/git-commit.zsh`
  - `scripts/_features/opencode/opencode-tools.zsh`
- **Description**: Confirm that any scripts that call `git-scope` (especially `git-commit-context`) still behave correctly with the native binary output; if output format differences break consumers, either (a) update consumers to be format-agnostic, or (b) define a stable machine-readable mode in the native binary and switch consumers to it.
- **Dependencies**:
  - Task 3.2
- **Complexity**: 7
- **Acceptance criteria**:
  - `git-commit-context` still prints a scope summary and does not error when `git-scope` is present.
  - `opencode-tools` continues to work when it chooses to include `git-scope` context (best-effort).
- **Validation**:
  - `zsh -lic 'command -v git-scope >/dev/null 2>&1 && command -v git-commit-context >/dev/null 2>&1 && git-commit-context --stdout >/dev/null 2>&1 || true'`

## Sprint 4: Archive codex-tools (legacy Zsh) and de-wire the codex feature
**Goal**: Archive the legacy Zsh `codex-tools` dispatcher + completion + docs + tests, stop generating the cached wrapper, and update the `codex` feature so it no longer expects repo-local `codex-tools.zsh`.
**Demo/Validation**:
- Command(s): `zsh -lic 'print -r -- ${ZSH_FEATURES-}; command -v codex-tools || true'`
- Verify: Enabling `codex` feature no longer errors due to missing legacy files; `codex-tools` resolves to the native binary when installed.

### Task 4.1: Move legacy codex-tools files into archive
- **Location**:
  - `scripts/_features/codex/codex-tools.zsh`
  - `scripts/_features/codex/_completion/_codex-tools`
  - `docs/cli/codex-cli-helpers.md`
  - `tests/codex-tools-groups.test.zsh`
  - `tests/codex-tools-rate-limits-async.test.zsh`
  - `archive/legacy-zsh-cli-tools/scripts/_features/codex/codex-tools.zsh`
  - `archive/legacy-zsh-cli-tools/scripts/_features/codex/_completion/_codex-tools`
  - `archive/legacy-zsh-cli-tools/docs/cli/codex-cli-helpers.md`
  - `archive/legacy-zsh-cli-tools/tests/codex-tools-groups.test.zsh`
  - `archive/legacy-zsh-cli-tools/tests/codex-tools-rate-limits-async.test.zsh`
- **Description**: Archive the legacy codex dispatcher implementation, its completion file, its docs page, and its legacy tests under `archive/legacy-zsh-cli-tools/` while keeping the rest of the `codex` feature (e.g., secrets helpers) intact.
- **Dependencies**:
  - Task 1.2
  - Task 1.3
- **Complexity**: 6
- **Acceptance criteria**:
  - Legacy `codex-tools` code and completion are no longer present under active `scripts/_features/codex/`.
  - Legacy codex-tools tests are no longer executed by `./tests/run.zsh`.
- **Validation**:
  - `test ! -f scripts/_features/codex/codex-tools.zsh && test -f archive/legacy-zsh-cli-tools/scripts/_features/codex/codex-tools.zsh`

### Task 4.2: Update codex feature init to stop sourcing legacy codex-tools and legacy completion
- **Location**:
  - `scripts/_features/codex/init.zsh`
- **Description**: Remove references to `codex-tools.zsh` and the legacy completion directory from the `codex` feature init. Keep other codex feature scripts enabled as-is (aliases and secret helpers can remain, pointing to the external `codex-tools` binary if present).
- **Dependencies**:
  - Task 4.1
- **Complexity**: 5
- **Acceptance criteria**:
  - Enabling `codex` feature does not attempt to source missing legacy files.
  - `scripts/_features/codex/alias.zsh` remains valid (aliases still point to `codex-tools`).
- **Validation**:
  - `ZDOTDIR="$PWD" ZSH_FEATURES=codex zsh -lc 'source "$ZDOTDIR/bootstrap/bootstrap.zsh" >/dev/null 2>&1; echo ok'`

### Task 4.3: Remove cached wrapper generation for codex-tools and clean stale wrappers
- **Location**:
  - `scripts/_internal/wrappers.zsh`
  - `cache/wrappers/bin/codex-tools`
- **Description**: Stop generating the `codex-tools` cached wrapper when the `codex` feature is enabled, and remove any stale `cache/wrappers/bin/codex-tools` so it cannot shadow a native binary.
- **Dependencies**:
  - Task 4.1
  - Task 4.2
- **Complexity**: 5
- **Acceptance criteria**:
  - With `ZSH_FEATURES=codex`, wrapper generation does not create `$ZSH_CACHE_DIR/wrappers/bin/codex-tools`.
  - If a native `codex-tools` binary exists, `command -v codex-tools` resolves to it (not cache).
- **Validation**:
  - `ZDOTDIR="$PWD" ZSH_CACHE_DIR="$PWD/cache" ZSH_FEATURES=codex zsh -lc 'source "$ZDOTDIR/scripts/_internal/wrappers.zsh" && _wrappers::ensure_all >/dev/null 2>&1 || true; test ! -f "$ZSH_CACHE_DIR/wrappers/bin/codex-tools"'`

## Sprint 5: Documentation cleanup + repo validation
**Goal**: Update top-level docs to reflect the migration, keep archived docs discoverable, and ensure repo checks/tests pass after removing the legacy implementations from active paths.
**Demo/Validation**:
- Command(s): `./tools/check.zsh && ./tests/run.zsh`
- Verify: Checks pass; docs point to archive and/or native tool locations; no broken internal references.

### Task 5.1: Update user-facing docs to reflect “native binaries + archived legacy”
- **Location**:
  - `README.md`
  - `CHANGELOG.md`
  - `scripts/_internal/README.md`
  - `docs/cli/fzf-tools.md`
  - `docs/cli/git-scope.md`
  - `docs/cli/codex-cli-helpers.md`
- **Description**: Remove the three tools from the “Built-in CLI Tools” list (or reclassify them as external/native). Replace the original docs pages with small stubs that link to (a) the archived legacy docs under `archive/legacy-zsh-cli-tools/docs/cli/` and (b) the new canonical docs location for the native binaries (e.g., their own repo).
- **Dependencies**:
  - Task 2.1
  - Task 3.1
  - Task 4.1
- **Complexity**: 4
- **Acceptance criteria**:
  - `README.md` no longer claims these are implemented in this repo.
  - Each stub doc clearly links to the archived legacy doc path.
- **Validation**:
  - `rg -n \"\\(docs/cli/(fzf-tools|git-scope)\\.md\\)|codex-cli-helpers\\.md\" README.md docs/cli -S`

### Task 5.2: Run repo verification commands
- **Location**:
  - `DEVELOPMENT.md`
- **Description**: Run the required checks after code moves/edits. Prefer `./tools/check.zsh` (includes completion lint) and `./tests/run.zsh`.
- **Dependencies**:
  - Task 5.1
- **Complexity**: 3
- **Acceptance criteria**:
  - `./tools/check.zsh` exits 0.
  - `./tests/run.zsh` exits 0.
- **Validation**:
  - `./tools/check.zsh`
  - `./tests/run.zsh`

### Task 5.3: Validate interactive completion behavior (native + aliases)
- **Location**:
  - `scripts/interactive/completion.zsh`
  - `docs/cli/fzf-tools.md`
  - `docs/cli/git-scope.md`
  - `docs/cli/codex-cli-helpers.md`
- **Description**: After removing repo-shipped completions for these tools, verify that completion still works via the native installation (e.g., Homebrew `share/zsh/site-functions`) and decide whether you want to keep alias completion bindings (`ft`, `gs`, `cx`) via minimal `compdef`-only files (no completion logic) or accept losing alias-specific completion.
- **Dependencies**:
  - Task 5.1
- **Complexity**: 5
- **Acceptance criteria**:
  - If `git-scope` is installed, its completion function is discoverable by `compinit` (e.g., `_git-scope` can be autoloaded).
  - If `fzf-tools` / `codex-tools` are installed, their completion functions are discoverable by `compinit`.
  - Documented instructions exist for rebuilding the compdump when completion sources change (e.g., `rz` / `compinit-reset`).
- **Validation**:
  - `ZDOTDIR="$PWD" zsh -ic 'autoload -Uz compinit; compinit -i -d "$ZSH_COMPDUMP"; command -v git-scope >/dev/null 2>&1 && whence -w _git-scope >/dev/null 2>&1 || true'`
  - `ZDOTDIR="$PWD" zsh -ic 'autoload -Uz compinit; compinit -i -d "$ZSH_COMPDUMP"; command -v fzf-tools >/dev/null 2>&1 && whence -w _fzf-tools >/dev/null 2>&1 || true'`
  - `ZDOTDIR="$PWD" zsh -ic 'autoload -Uz compinit; compinit -i -d "$ZSH_COMPDUMP"; command -v codex-tools >/dev/null 2>&1 && whence -w _codex-tools >/dev/null 2>&1 || true'`

## Testing Strategy
- Unit: keep existing focused Zsh tests for remaining tools; archive tests that only exercise the removed legacy implementations.
- Integration: `./tools/check.zsh` and `./tools/check.zsh --completions` to ensure completion lint still passes for what remains.
- E2E/manual: start a fresh interactive shell (`zsh -il`) and verify `command -v fzf-tools/git-scope/codex-tools` resolves to native binaries (not `$ZSH_CACHE_DIR/wrappers/bin`), and that there are no startup errors.

## Risks & gotchas
- Cached wrapper shadowing: stale executables in `cache/wrappers/bin` can keep intercepting tool names even after code is archived unless explicitly cleaned.
- Downstream format coupling: scripts like `git-commit-context` may implicitly rely on legacy `git-scope` output shape/colors; native output differences can break expectations.
- Completion regressions: removing repo-shipped completions may reduce completion quality unless native completions are installed and discoverable via `fpath`.
- Compdump staleness: after moving/removing completion files, users may need to rebuild `$ZSH_COMPDUMP` (`rz` / `compinit-reset`).
- Archived doc link rot: moved markdown may have relative links (e.g., screenshots) that break unless paths are updated or assets are mirrored.

## Rollback plan
- Soft rollback: restore wrapper generation + legacy scripts by moving files back from `archive/legacy-zsh-cli-tools/` to their original locations and regenerating wrappers (`rm -rf "${ZSH_CACHE_DIR:-$PWD/cache}/wrappers" && start a new shell`).
- Hard rollback: `git revert` the migration commit(s) (including wrapper/doc/test changes) to return to the prior Zsh implementations.
