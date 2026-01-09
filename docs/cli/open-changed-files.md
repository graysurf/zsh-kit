# open-changed-files

Open a set of changed files in Visual Studio Code for quick review.

This tool is intended to be used after an LLM edits files, so you can immediately inspect the touched files in VSCode.

## TL;DR

- Open explicit files (default): `./tools/open-changed-files.zsh path/to/a path/to/b`
- Open from stdin (no args): `printf "%s\\n" path/to/a path/to/b | ./tools/open-changed-files.zsh`
- Open git changes: `./tools/open-changed-files.zsh --git`
- Preview commands: `./tools/open-changed-files.zsh --dry-run ...`

## Behavior

- If the `code` CLI is not found:
  - Normal mode: does nothing, exits `0`, prints nothing.
  - `--dry-run`: still prints planned `code ...` invocations.
- Default maximum opened files: `5` (configurable).
- Workspace behavior:
  - Default (`--workspace-mode pwd`): open everything in a single VSCode window with workspace set to `$PWD`.
  - `--workspace-mode git`: search up to 5 parent directories for a `.git` root per file, and open different git roots in different VSCode windows.
  - When opening many files (after increasing `--max-files`): opens per-workspace in batches of 50 to avoid argv limits (first batch uses `--new-window`, subsequent batches use `--reuse-window`).

## Usage

```zsh
./tools/open-changed-files.zsh [--list|--git] [--workspace-mode pwd|git] [--dry-run] [--verbose] [--max-files N] [--] [files...]
```

### Modes

- `--list` (default): open file paths from CLI args; when no args are provided, read newline-delimited paths from stdin.
- `--git`: open changed files from git:
  - staged + unstaged + untracked
  - deleted paths are skipped

### Options

- `--dry-run`: print the planned `code ...` commands without executing them
- `--verbose`: explain no-op behavior and ignored paths (stderr only)
- `--workspace-mode pwd|git`: workspace strategy (default: `pwd`)
- `--max-files N`: cap opened files (default: `5`)

### Environment

- `OPEN_CHANGED_FILES_SOURCE`: `list` (default) or `git`
- `OPEN_CHANGED_FILES_WORKSPACE_MODE`: `pwd` (default) or `git`
- `OPEN_CHANGED_FILES_MAX_FILES`: max files to open (default: `5`)
