# 📂 Gscope: Git Scope Viewers

Gscope is a collection of tree-based Git viewers for inspecting your working directory by status category. It helps you understand what has changed, what is staged, and what remains untracked, using visual hierarchy.

---

## 📦 Use Cases

- Review project structure before making a commit
- Visualize modified vs. staged vs. untracked files
- Avoid committing files unintentionally by seeing their layout
- Debug repo state during complex merges or rebases

---

## 🛠 Commands

### `gscope`

📂 Show full directory tree of all files tracked by Git (excluding ignored/untracked)

```bash
gscope
```

Displays a full tree of files currently under version control.

---

### `gscope-staged`

📂 Show tree of staged files (ready to be committed)

```bash
gscope-staged
```

Only includes files in the staging area.

---

### `gscope-modified`

📂 Show tree of modified files (not yet staged)

```bash
gscope-modified
```

Lists files changed but not added to staging.

---

### `gscope-all`

📂 Show tree of all changed files (staged + modified)

```bash
gscope-all
```

Combined view of `gscope-staged` and `gscope-modified`.

---

### `gscope-untracked`

📂 Show tree of untracked files (new files not yet added)

```bash
gscope-untracked
```

Lists new files not yet staged, ignoring those excluded via `.gitignore`.

---

## 🧱 Implementation Notes

- Uses `git diff --name-only`, `git ls-files`, and `awk` for full path decomposition
- `tree --fromfile` renders deeply nested directory views from flat file paths
- Outputs include clear warnings when no files match the filter
- Works best with `tree` installed and available in `$PATH`

---

## 🧠 Summary

Gscope helps you reason about your Git workspace in a visual way. Each command is meant to answer a simple question like:

- What have I staged?
- What’s new in the working tree?
- What’s untracked?
- What’s the full layout of my repo?

It’s a small but powerful addition to your CLI Git workflow.
