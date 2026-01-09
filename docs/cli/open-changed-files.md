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
- Workspace grouping:
  - For each file, search up to 5 parent directories for a `.git` root.
  - Files in different git roots open in different VSCode windows (`code --new-window` per root).
  - Files with no git root within 5 levels are grouped under `$PWD` as the workspace.
- When opening many files (after increasing `--max-files`): opens per-workspace in batches of 50 to avoid argv limits.

## Usage

```zsh
./tools/open-changed-files.zsh [--list|--git] [--dry-run] [--max-files N] [--] [files...]
```

### Modes

- `--list` (default): open file paths from CLI args; when no args are provided, read newline-delimited paths from stdin.
- `--git`: open changed files from git:
  - staged + unstaged + untracked
  - deleted paths are skipped

### Options

- `--dry-run`: print the planned `code ...` commands without executing them
- `--max-files N`: cap opened files (default: `5`)

### Environment

- `OPEN_CHANGED_FILES_SOURCE`: `list` (default) or `git`
- `OPEN_CHANGED_FILES_MAX_FILES`: max files to open (default: `5`)

