
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
🔖 7e1a706 feat(members): support manual memberNo input and unify fallback account creation error
👤 terrylin <10785178+graysurf@users.noreply.github.com>
📅 2025-06-04 18:41:35 +0800

📝 Commit Message:
   feat(members): support manual memberNo input and unify fallback account creation error

   - Added `memberNo` field to CompleteProfileInput, MemberProfile, and schema.gql
   - Updated member service to pass memberNo into TunGroupService when creating/updating profile
   - Added fallback error `ACCOUNT_CREATION_FAILED` for unknown failures during account creation
   - Replaced InternalServerErrorException with structured AppError for consistency

📄 Changed files:
   ➤ [M] libs/graphql-api/src/members/members.mutations.ts  [+4 / -4]
   ➤ [M] libs/graphql-objects/src/member-profiles/member-profiles.objects.ts  [+3 / -0]
   ➤ [M] libs/graphql-objects/src/members/members.inputs.ts  [+3 / -0]
   ➤ [M] libs/integrations/tun-group/src/tun-group.interface.ts  [+1 / -0]
   ➤ [M] libs/integrations/tun-group/src/tun-group.service.ts  [+1 / -0]
   ➤ [M] libs/members/src/errors/members.account.errors.ts  [+9 / -0]
   ➤ [M] libs/members/src/services/members.service.ts  [+26 / -11]
   ➤ [M] schema.gql  [+262 / -276]

📂 Directory tree:
.
├── libs
│   ├── graphql-api
│   │   └── src
│   │       └── members
│   │           └── members.mutations.ts
│   ├── graphql-objects
│   │   └── src
│   │       ├── member-profiles
│   │       │   └── member-profiles.objects.ts
│   │       └── members
│   │           └── members.inputs.ts
│   ├── integrations
│   │   └── tun-group
│   │       └── src
│   │           ├── tun-group.interface.ts
│   │           └── tun-group.service.ts
│   └── members
│       └── src
│           ├── errors
│           │   └── members.account.errors.ts
│           └── services
│               └── members.service.ts
└── schema.gql

16 directories, 8 files
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
