
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

### `gscope-commit`

📂 Show tree and metadata of a specific commit

```bash
gscope-commit HEAD~1
gscope-commit abc1234
```

This command displays:
- The commit hash, message, author, and date
- A list of all changed files in the commit, with:
  - Status (A, M, D, etc.)
  - Added and removed lines
- A reconstructed directory tree of those files

Useful for:
- Inspecting what was touched in a given commit
- Understanding structural impact of a change
- Reviewing change scope before squashing, rebasing, or cherry-picking

---

### 🧪 Example

```bash
gscope-commit HEAD~6
```

**Output:**

```
🔖 c1597ed feat(rbac): allow EDITOR role access to admin and member APIs
👤 terrylin <10785178+graysurf@users.noreply.github.com>
📅  Thu Jun 5 08:35:48 2025 +0800

📄 Changed files:
  ➤ [M] apps/api/src/app/member-export.controller.ts                        [+1 / -1]
  ➤ [M] libs/graphql-api/src/member-profiles/member-profiles.mutations.ts   [+1 / -1]
  ➤ [M] libs/graphql-api/src/member-profiles/member-profiles.queries.ts     [+3 / -3]
  ➤ [M] libs/graphql-api/src/members/members.admin.mutations.ts             [+2 / -2]
  ➤ [M] libs/graphql-api/src/members/members.admin.queries.ts               [+2 / -2]
  ➤ [M] libs/graphql-api/src/notifications/notifications.mutations.ts       [+6 / -6]
  ➤ [M] libs/graphql-api/src/notifications/notifications.queries.ts         [+2 / -2]

📂 Directory tree:
.
├── apps
│   └── api
│       └── src
│           └── app
│               └── member-export.controller.ts
└── libs
    └── graphql-api
        └── src
            ├── member-profiles
            │   ├── member-profiles.mutations.ts
            │   └── member-profiles.queries.ts
            ├── members
            │   ├── members.admin.mutations.ts
            │   └── members.admin.queries.ts
            └── notifications
                ├── notifications.mutations.ts
                └── notifications.queries.ts
```

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
