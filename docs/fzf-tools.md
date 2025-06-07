# 🚀 Fzf Tools: Interactive CLI Navigator

Fzf Tools is a modular, keyboard-driven launcher that lets you browse and act on files, Git status, processes, and shell history using fuzzy search. It’s designed for developers who want quick, contextual interactions directly from the terminal.

---

## 📦 Use Cases

- Open recently changed files in your editor via Git commit inspection
- Jump into any directory by previewing structure with `eza`
- Preview file contents with syntax highlighting using `bat`
- Search and replay shell history or kill processes interactively
- Integrate `fzf-tools` into aliases or scripts as a structured subcommand

---

## 🛠 Commands

### `fzf-tools history`

📜 Search and run from recent shell commands

```bash
fzf-tools history
```

Great for recalling complex or recently used one-liners without retyping.

---

### `fzf-tools cd`

📂 Browse and enter directories interactively

```bash
fzf-tools cd
```

Uses `eza` to preview directory contents and `fzf` to select one.

---

### `fzf-tools directory`

📁 Pick a file, then jump to its parent directory

```bash
fzf-tools directory
```

Quick way to navigate to where work is happening.

---

### `fzf-tools file`

📝 Open a file using `vi` after previewing its contents with `bat`

```bash
fzf-tools file
```

---

### `fzf-tools vscode`

🧠 Open a file in VSCode (instead of vi), with fuzzy selection

```bash
fzf-tools vscode
```

Same behavior as `fzf-tools file`, but uses your GUI editor.

---

### `fzf-tools git-status`

📂 Pick and preview modified files from `git status`

```bash
fzf-tools git-status
```

Shows inline diffs and lets you quickly inspect file changes.

---

### `fzf-tools git-commit`

🔍 Browse commit history, preview files in any commit, and open in VSCode

```bash
fzf-tools git-commit
```

You can enter a hash like `HEAD~1`, or interactively pick from log.

**Preview includes:**
- `bat`-highlighted file content
- Commit-specific snapshot
- Automatic temp file export to open in VSCode

---

### `fzf-tools kill`

💀 Select and terminate one or more running processes

```bash
fzf-tools kill
```

Uses `ps` and `xargs kill`, with support for multiselect.

---

## 🧠 Summary

Fzf Tools enhances your terminal flow by bridging common developer tasks into a single, discoverable command. With `fzf`, `bat`, `eza`, and Git integration, you get a lightweight but powerful toolbox for navigating projects, managing sessions, and inspecting your codebase—without leaving the shell.
