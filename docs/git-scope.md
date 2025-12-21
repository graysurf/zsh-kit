# 📂 git-scope: Git Scope Viewers

`git-scope` is a collection of tree-based Git viewers for inspecting your working directory or commits by status category. It helps you understand what has changed, what is staged, and what remains untracked, using visual hierarchy.

---

## 📦 Use Cases

- Review project structure before making a commit
- Visualize unstaged vs. staged vs. untracked files
- Inspect changes introduced by a specific commit
- Debug repo state during complex merges or rebases
- Audit commit scope and verify change impact

---

### 💡 Output Preview

The following is a sample output from `git-scope`, illustrating how changed files are listed by status  
(e.g., `[-]` for tracked, `[M]` for unstaged), followed by a visual directory tree. This format is shared  
across most subcommands, providing a consistent, readable view of file status and structure.

```text
🍎 yourname on MacBook ~ 🐋 gke-dev 🐳 orbstack
12:00:42.133 ✔︎ git-scope

📂 Show full directory tree of all files tracked by Git (excluding ignored/untracked)

📄 Changed files:
  ➤ [-] .gitignore
  ➤ [-] .zprofile
  ➤ [-] .zshrc
  ➤ [-] README.md
  ➤ [-] scripts/login.zsh
  ➤ [-] scripts/macos.zsh
  ➤ [-] tools/git/git-summary
  ➤ [-] tools/random_emoji_cmd.zsh

📂 Directory tree:
.
├── .gitignore
├── .zprofile
├── .zshrc
├── README.md
├── scripts
│   ├── login.zsh
│   ├── macos.zsh
└── tools
    ├── git
    │   └── git-summary
    └── random_emoji_cmd.zsh
```

---

## 🛠 Commands

### `git-scope`

📂 Show full directory tree of all files tracked by Git (excluding ignored/untracked)

```bash
git-scope
```

Displays a full tree of files currently under version control. You can pass optional path prefixes or use `-p` to print file contents.

---

### `git-scope staged`

📂 Show tree of staged files (ready to be committed)

```bash
git-scope staged
```

Only includes files in the staging area. Supports `-p` to print their contents.

---

### `git-scope unstaged`

📂 Show tree of unstaged files (not yet staged)

```bash
git-scope unstaged
```

Lists files changed but not added to staging. Use `-p` to print file contents.

---

### `git-scope all`

📂 Show tree of all changed files (staged and unstaged)

```bash
git-scope all
```

Combined view of `staged` and `unstaged`. Can print all files with `-p`.

---

### `git-scope untracked`

📂 Show tree of untracked files (new files not yet added)

```bash
git-scope untracked
```

Lists new files not yet staged, ignoring those excluded via `.gitignore`.

---

### `git-scope commit <hash> [-p]`

🔍 Show tree and metadata of a specific commit (historical inspection mode)

```bash
git-scope commit HEAD~1
git-scope commit abc1234 -p
```

This command inspects a specific Git commit and displays:

- 🔖 Commit hash, author, date, and formatted commit message
- 📄 List of changed files in the commit:
  - Status (A, M, D, etc.)
  - Line counts for additions and deletions (from `--numstat`)
- 📂 Reconstructed directory tree of affected files

Optional:

- `-p`, `--print`: Print contents of each file from HEAD or working tree
  - Text files are printed inline
  - Binary files are replaced with a placeholder

This command differs from others in that it inspects historical commit objects rather than your current working directory.

Useful for:

- Code reviews and commit audits
- Inspecting a squashed or rebased history
- Understanding structural impact of changes

**Example:**

```bash
git-scope commit HEAD~6
```

**Output:**

```text
🔖 7e1a706 feat(members): support manual memberNo input and unify fallback account creation error
👤 graysurf <10785178+graysurf@users.noreply.github.com>
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

   📊 Total: +309 / -291

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

- Uses `git diff`, `git show`, `git ls-files` for data collection
- Directory trees rendered via `tree --fromfile`
- Uses `awk` to reconstruct full directory hierarchy
- File content display supports both text and binary-aware output
- Internally manages file state parsing using unified helpers

---

## 🧠 Summary

`git-scope` helps you reason about your Git repository visually. Whether you're preparing to commit or reviewing a historical change, it gives you a structured way to see what’s going on — file by file, tree by tree.
