# 🔐 Glock: Git Commit Locking System

Glock is a lightweight commit-locking utility for Git repositories. It allows you to "lock" the current commit hash under a named label, restore it later, list and compare saved locks, and even tag them. This helps developers maintain checkpoints during complex feature development or hotfix workflows.

---

## 📦 Use Cases

- Save a known-good commit before refactoring (`glock refactor-start`)
- Lock a hotfix base before applying changes (`glock hotfix-base`)
- Tag commits after QA review using saved labels (`glock-tag qa-passed v1.1.2`)
- Roll back instantly to a locked commit (`gunlock refactor-start`)
- View or diff commit checkpoints for auditing

---

## 🛠 Commands

### `glock <label> [note] [commit]`

Locks the current commit (or a specific one) under a label.

- Stores commit hash, optional note, and timestamp.
- Lock files live in: `$ZSH_CACHE_DIR/glocks/`
- Also updates `<repo>-latest` marker for recent access

```bash
glock dev-start "before breaking change"
glock release-candidate "for QA team" HEAD~1
```

---

### `gunlock [label]`

Restores the commit saved under the given label via `git reset --hard`. Prompts before action.

```bash
gunlock dev-start
```

---

### `glock-list`

Lists all saved glocks for the current repo, including:

- Label name
- Commit hash
- Note (if any)
- Commit subject
- Timestamp
- Marks latest label with ⭐

---

### `glock-copy <src-label> <dst-label>`

Duplicates a saved glock (useful for branching or preserving milestones).

```bash
glock-copy qa-ready staging-review
```

---

### `glock-delete [label]`

Deletes a saved glock. Prompts before removal. Also cleans up latest marker if applicable.

```bash
glock-delete dev-start
```

---

### `glock-diff <label1> <label2>`

Compares two saved glocks by showing commits between them using `git log`.

```bash
glock-diff alpha beta
```

---

### `glock-tag <label> <tag-name> [-m <msg>] [--push]`

Creates a Git tag from a saved glock. Optionally pushes it to origin and deletes it locally.

```bash
glock-tag rc-1 v1.2.0 -m "Release Candidate 1" --push
```

---

## 🧱 Implementation Notes

- All lock files are stored under: `$ZSH_CACHE_DIR/glocks`
- File format:
  - Line 1: `commit-hash # optional note`
  - Line 2: `timestamp=YYYY-MM-DD HH:MM:SS`
- `gunlock` and `glock-tag` read from these files
- `glock-list` sorts using timestamps for recent-first ordering
- `basename` of `git rev-parse --show-toplevel` is used to isolate per-repo locking

---

## 📤 Output Preview

A sample `glock-list` might look like:

```
🔐 Glock list for [my-repo]:

 - 🏷️  tag:    dev-start  ⭐ (latest)
   🧬 commit:  5a1f9e3
   📄 message: Init core structure
   📝 note:    before breaking change
   ⏰ time:    2025-06-06 13:45:12

 - 🏷️  tag:    release
   🧬 commit:  d0e4ca2
   📄 message: Merge pull request #12 from release
   ⏰ time:    2025-06-05 18:12:00
```

---

## 🧼 Cleanup Tip

To clear all glocks in current repo:

```bash
rm ~/.config/zsh/cache/glocks/$(basename `git rev-parse --show-toplevel`)*.lock
```

---

## 🧠 Summary

Glock enables Git users to mark meaningful checkpoints in a manual but structured way. It is ideal for monorepo workflows, hotfix backouts, and solo dev snapshots.