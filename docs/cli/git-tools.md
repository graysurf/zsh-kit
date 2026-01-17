# 🧰 git-tools: Git Helper Router

`git-tools` is a grouped CLI that routes to the Git helper functions shipped in this config.
It keeps resets, commit helpers, branch cleanup, and utilities under a single entrypoint.

---

## 📦 Use Cases

- Run safe reset flows with prompts and rollback awareness
- Generate commit context or convert a commit into a stash entry
- Clean merged branches with base/squash awareness
- Copy staged diffs or jump to the repo root
- Open repo/branch/commit/PR pages with `git-open`

---

## 🛠 Commands

### `git-tools`

Show top-level help and available groups.

```bash
git-tools
git-tools help
git-tools list
```

---

### `git-tools <group> help`

Show commands for a specific group.

```bash
git-tools reset help
git-tools utils help
```

---

### `git-tools utils`

Utility helpers for zipping, diff copying, repo roots, and commit hash resolution.

#### `git-tools utils zip`

Create a zip archive from `HEAD` (tracked files only) named `backup-<short-hash>.zip`.

```bash
git-tools utils zip
```

#### `git-tools utils copy-staged [--stdout|--both]`

Copy staged diff to clipboard (default), or print to stdout.  
Alias: `git-tools utils copy`

```bash
git-tools utils copy-staged
git-tools utils copy-staged --stdout
```

#### `git-tools utils root`

Jump to the Git root directory of the current repo.

```bash
git-tools utils root
```

#### `git-tools utils commit-hash <ref>`

Resolve a ref (tag/branch/commit) to a commit SHA.  
Alias: `git-tools utils hash`

```bash
git-tools utils commit-hash HEAD~1
```

---

### `git-tools reset`

Reset helpers with confirmation prompts and reflog-aware safety.

#### `git-tools reset soft [N]`

Soft reset `HEAD~N` (default `N=1`), keeping changes staged.

```bash
git-tools reset soft
git-tools reset soft 2
```

#### `git-tools reset mixed [N]`

Mixed reset `HEAD~N`, keeping changes but unstaging them.

```bash
git-tools reset mixed 3
```

#### `git-tools reset hard [N]`

Hard reset `HEAD~N` after confirmation (destructive for tracked changes).

```bash
git-tools reset hard
```

#### `git-tools reset undo`

Undo the last HEAD movement using reflog (HEAD@{1}).  
If the working tree has changes, you choose soft/mixed/hard behavior interactively.

```bash
git-tools reset undo
```

#### `git-tools reset back-head`

Checkout `HEAD@{1}` (previous HEAD position).  
May lead to detached HEAD depending on history.

```bash
git-tools reset back-head
```

#### `git-tools reset back-checkout`

Return to the previous branch based on reflog checkout entries.

```bash
git-tools reset back-checkout
```

#### `git-tools reset remote [options]`

Overwrite the current local branch with a remote-tracking branch (dangerous).

```bash
git-tools reset remote --ref origin/main
git-tools reset remote -r origin -b main --prune --clean
```

Options:

- `-r, --remote <name>` Remote name (default: upstream or `origin`)
- `-b, --branch <name>` Remote branch name (default: upstream or current)
- `--ref <remote/branch>` Shortcut for remote + branch
- `--no-fetch` Skip `git fetch`
- `--prune` Use `git fetch --prune`
- `--clean` Optionally run `git clean -fd` after reset
- `--set-upstream` Set upstream to `<remote>/<branch>`
- `-y, --yes` Skip confirmations

---

### `git-tools commit`

Commit helpers for context generation and commit-to-stash conversion.

#### `git-tools commit context [--stdout|--both] [--no-color]`

Generate a Markdown summary of staged changes, copy it to clipboard,  
and include staged file contents.  
Uses `git-scope staged` for scope/tree output.

```bash
git-tools commit context
git-tools commit context --stdout --no-color
```

#### `git-tools commit context-json [--stdout|--both] [--pretty] [--bundle] [--out-dir <path>]`

Generate a JSON manifest for staged changes and write the staged diff as a standalone `.patch` file.

- Writes:
  - `<out-dir>/commit-context.json`
  - `<out-dir>/staged.patch`
- Default `<out-dir>` is `$(git rev-parse --git-dir)/commit-context` (usually `.git/commit-context`).
- `--bundle` prints/copies a single output containing both JSON + patch (good for pasting into an API).
- Alias: `git-tools commit json`.

```bash
git-tools commit context-json
git-tools commit context-json --stdout --bundle
git-tools commit context-json --out-dir ./commit-context --stdout --bundle --pretty
```

#### `git-tools commit to-stash [commit]`

Convert a commit into a stash entry (default: `HEAD`) and optionally drop it.  
Alias: `git-tools commit stash`

```bash
git-tools commit to-stash
git-tools commit to-stash HEAD~2
```

---

### `git-tools branch`

Branch cleanup helpers with base and squash awareness.

#### `git-tools branch cleanup [-b|--base <ref>] [-s|--squash]`

Delete local branches merged into a base ref (default: `HEAD`),  
optionally treating squash-merged branches as deletable.

```bash
git-tools branch cleanup
git-tools branch cleanup --base main --squash
```

---

## 🧱 Implementation Notes

- `git-tools` is a dispatcher that routes to the `git-*` helper functions.
- Reset commands prompt before destructive actions; `reset remote` can overwrite local state.
- Clipboard flows rely on `set_clipboard` being available in the shell.
