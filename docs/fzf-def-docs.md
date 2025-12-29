# fzf-def Docblock Guidelines (Functions / Aliases)

This document defines how to write docblocks (comment blocks directly above function / alias
definitions) so that `fzf-tools def` / `fzf-tools function` / `fzf-tools alias` can show useful,
copy-friendly help in previews.

## Background & Goals

- `fzf-tools` renders “docblock above a definition + the actual definition”.
- Docblocks therefore become a searchable, copyable, in-context mini-doc.
- The goal is to keep “what I need at the moment of use” close to the definition:
  - What is it? (intent / scope)
  - How do I use it? (`Usage:` / examples)
  - Any side effects or risks? (edit files, kill, reset, push, delete, etc.)
  - Which environment variables affect it? (`Env:`)

Non-goals:

- Do not cram every detail into a docblock. Put complex narratives into `docs/`; docblocks should
  mainly guide usage and prevent misuse.

## Docblock Capture Rules (Must Read)

`fzf-tools` extracts docblocks using the following rules:

- It only captures consecutive `# ...` lines that are immediately above a function/alias definition.
- There must be **no blank line** between the docblock and the definition, otherwise the docblock is
  treated as “disconnected” and will not be attached.
- If you need visual separation *inside* a docblock, use an empty comment line, not a blank line:
  - ✅ `#`
  - ❌ (a real blank line)

Recommendations:

- Avoid sticking file-section “separator comments” to docblocks; they create noisy previews.
  - If you want to keep separators, insert a blank line between the separator and the docblock; keep
    the docblock directly attached to the definition.

## Taxonomy (What We Standardize)

This taxonomy is not meant to restrict naming. It defines the **minimum docblock requirements** per
kind of definition.

### A. User-facing command

Characteristics (any of the following):

- Expected to be executed directly by a human in the shell (not only called by other functions).
- Documented in `README.md` or `docs/*.md` as a command/tool.
- Uses readable kebab-case (e.g. `git-scope`, `fzf-tools`, `kill-port`).

Minimum: L2 (Summary + Usage)  
Recommended: for destructive/high-risk commands, use L3 (add Examples/Notes/Safety/Env).

### B. Dispatcher / Router

Characteristics:

- Has subcommands (`<command> ...`), or is a command-collection entrypoint like `fzf-tools`.

Minimum: L3 (must list subcommands + common examples).

### C. Public helper / API (reusable, but not primary CLI)

Characteristics:

- Primarily used by other scripts/functions, but may be invoked manually.
- Not necessarily `_`-prefixed (e.g. utilities, render/format helpers, collectors).

Minimum: L1 (Summary)  
Recommended: if it takes parameters, has a defined output format, or has side effects, use L2
(add Usage / Output).

### D. Internal helper (`_foo` / `__foo`)

Characteristics:

- Prefixed with `_` or `__` to indicate internal/private usage.

Minimum: L1 (one line is enough)  
Recommended: if the helper is non-obvious or has side effects (writes files, `cd`, `kill`, reads git
state, depends on external tools), add `Usage:` or `Notes:` (L2).

### E. Overrides / High-risk ops

Characteristics:

- Overrides builtins (e.g. `cd()`) or replaces common command behavior (e.g. `alias cat=...`).
- Creates obvious side effects (delete/reset/kill/push/system changes).

Minimum: L3, and it must include `Safety:` / `Notes:` to prevent misuse.

### F. Alias (shortcut)

Characteristics:

- `alias xx='...'`

Minimum (recommended policy):

- If an alias is non-obvious or has side effects: L1 (at least one-line summary).
- If an alias is an extremely obvious, low-risk abbreviation (e.g. `ga='git add'`): L0 is acceptable
  (not required), but incremental improvements are encouraged.

## Docblock Levels (L0–L3)

To keep the guideline actionable, docblocks are grouped into levels and mapped to the taxonomy.

- L0: no docblock (only for rare, fully obvious, low-risk aliases or one-off internals)
- L1: Summary (1 line)
- L2: Summary + Usage (typically 2–4 lines)
- L3: Full block (Summary + Usage + 1–3 sections: Options/Examples/Env/Output/Notes/Safety)

## Standard Layout (Preferred)

To keep previews consistent and easy to scan, standardize the *shape* of docblocks:

- L1 (one line): `# <name>: <summary>`
- L2/L3 (multi-line): start with a name/signature line, then a summary line:
  - `# <name> [args...]`
  - `# <summary>`

Then add `Usage:` and optional sections (`Examples:`, `Notes:`, `Env:`, `Safety:`) as needed.

## Preview Separators (fzf-tools)

For readability, `fzf-tools def` / `fzf-tools function` / `fzf-tools alias` wraps captured docblocks
with comment separator lines in the preview output (and therefore in the copied result).

- These separator lines are inserted at render time and are not part of the source docblock.
- Do not add `# -----` separator lines into docblocks themselves; keep docblocks focused on
  Summary/Usage and related sections.
- `FZF_DEF_DOC_SEPARATOR_PAD` (default: `2`) controls the extra width added to the separator line.

## Recommended Formats (Templates)

The guiding principles are: scannable, copyable, and consistent.

### 1) User-facing command (L2/L3)

```zsh
# my-command [optional] <required>
# Do one thing well; include key side effects if any.
# Usage: my-command [--flag] <required> [optional]
# Examples:
#   my-command foo
# Notes:
#   - Writes to clipboard.
#   - Requires a git repo.
my-command() {
  # ...
}
```

### 2) Dispatcher (L3)

```zsh
# my-tools
# Dispatcher for related subcommands.
# Usage: my-tools <command> [args]
# Notes:
# - Subcommands: alpha, beta, gamma
# Examples:
#   my-tools alpha
my-tools() {
  # ...
}
```

### 3) Internal helper `_foo` (L1/L2)

```zsh
# _my_helper: Normalize input and print canonical form.
# Usage: _my_helper <value>
_my_helper() {
  # ...
}
```

### 4) Alias (L1/L2)

```zsh
# kp: Alias of kill-port.
# Usage: kp [-9] <port>
alias kp='kill-port'
```

## Writing Guidelines (What to Include / Avoid)

### Header + Summary

Do:

- Use the Standard Layout (Preferred) section above.
- Start the summary with a verb; describe what it does, not how it is implemented.
- Prefer calling out scope and side effects (e.g. changes git state, writes files, kills processes).

Avoid:

- Implementation details (internal function names, awk/sed pipelines) in the summary.

### Usage

Recommended placeholders (for readability and consistency):

- Required params: `<arg>`; optional: `[arg]`
- Repeatable: `...` (e.g. `[path...]`)
- Flags: `[--flag]` or `[-f|--force]` (match actual parsing)

### Examples

Do:

- 1–3 examples; ensure they are copy-pastable.
- For risky behavior, use safe defaults or clearly explain the impact.

### Env / Output / Notes / Safety

Consider adding (L3) when:

- Env-driven behavior exists: list env vars and defaults (or “when unset” behavior).
- Output is structured: describe the output shape (multi-line, JSON, stdout/stderr behavior, etc.).
- Common pitfalls exist: put them under `Notes:`.
- High-risk behavior exists: explicitly label `Safety:` or `DANGER:` (irreversible ops, kill, reset,
  delete).

## Rollout Plan

### 1) Baseline (snapshot)

Current snapshot of first-party `.zsh` scan (numbers will change over time):

- functions: `176` definitions, `118` with docblocks
  - internal (`_` prefix): `77`, `43` with docblocks
  - non-internal: `99`, `75` with docblocks
- aliases: `94` definitions, `57` with docblocks

Files with relatively larger gaps (useful for prioritizing backfill):

- `scripts/fzf-tools.zsh`: many aliases/helpers; prioritize user-facing commands + non-obvious helpers
- `scripts/git/git-tools.zsh`: many workflow aliases; prioritize non-obvious + risky aliases
- `scripts/shell-utils.zsh`: includes overrides and kill utilities; ensure risky items have Safety/Notes
- `scripts/eza.zsh`: mostly aliases; easy wins via one-line summaries (L1)

### 2) Targets (adjustable)

- Category A/B (user-facing + dispatcher): 100% coverage, at least L2
- Category E (override/high-risk): 100% coverage, must be L3 with Safety/Notes
- Category D (internal helpers): no need for 100%, but non-obvious/side-effect helpers must be at least L1
- Category F (aliases): backfill non-obvious/risky ones to L1 first; then iterate

### 3) Review checklist (for code review)

- Which category (A–F) is this function/alias?
- Is the docblock attached (no blank line between docblock and definition)?
- Does it meet the minimum level (L1/L2/L3) for the category?
- Does `Usage:` match the actual argument parsing?
- Are side effects / risk / dependencies (git repo, external commands, env vars) clearly stated?

Optional: if you want to track coverage periodically, add a `tools/` audit command that prints the
baseline + a gap list, and reference it in reviews/PRs.

## Appendix: Existing Styles & Convergence

This repo currently uses two common patterns (both acceptable; we want convergence towards
“signature + summary + usage”):

1) Signature first (e.g. `# codex-commit-with-scope [extra prompt...]`)
2) `name: summary` (e.g. `# kill-port: Kill process(es) ...`)

Recommended convergence:

- For user-facing commands/dispatchers (A/B): prefer signature-first and ensure a `Usage:` line exists.
- For internal helpers (D): keep it 1–2 lines, but make “what it does / input-output” clear.
