# 🧩 OpenCode CLI Helpers: Opt-In Prompt Wrappers

This feature is disabled by default. Enable it by including `opencode` in `ZSH_FEATURES` (e.g. in your home `~/.zshenv`).

`scripts/_features/opencode/opencode-tools.zsh` adds an `opencode-tools` dispatcher plus `opencode-*` helpers that run shared prompt templates under `$ZDOTDIR/prompts`.

---

## 🛠 Commands

### `opencode-tools <command> [args...]`

Dispatcher for the helpers below:

```bash
opencode-tools advice "How to optimize Zsh startup time?"
```

Alias:

```bash
opencode-tools advice "How to optimize Zsh startup time?"
```

---

### `opencode-tools commit-with-scope [-p] [extra prompt...]`

Runs the `semantic-commit` skill and attaches any optional guidance you pass in.

Fallback:

- If `semantic-commit` skill is not installed (missing `$CODEX_HOME/skills/tools/devex/semantic-commit/SKILL.md`), the command falls back to a local interactive Conventional Commit flow (and `-p` still pushes).

Options:

- `-p`: Push the committed changes to the remote repository.

```bash
opencode-tools commit-with-scope -p "Prefer terse subject lines"
```

---

### `opencode-tools advice [question...]`

Runs the `actionable-advice` prompt template. If you omit the argument, it will prompt for a question.

```bash
opencode-tools advice "How to speed up my Zsh completion?"
```

---

### `opencode-tools knowledge [concept...]`

Runs the `actionable-knowledge` prompt template. If you omit the argument, it will prompt for a concept.

```bash
opencode-tools knowledge "What is a closure in programming?"
```

---

## ⚙️ Configuration

- `OPENCODE_CLI_MODEL` (optional; forwarded to `opencode run -m`)
- `OPENCODE_CLI_VARIANT` (optional; forwarded to `opencode run --variant`)
