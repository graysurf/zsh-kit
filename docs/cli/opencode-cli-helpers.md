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
oc advice "How to optimize Zsh startup time?"
```

---

### `opencode-tools <prompt...>` (raw prompt)

If the first argument is not a known command, `opencode-tools` treats everything as a raw prompt:

```bash
opencode-tools "advice about X"
```

To force raw prompt mode when your prompt starts with a command word, use `--` (or `prompt`):

```bash
opencode-tools -- "advice about X"
opencode-tools prompt "advice about X"
```

---

### `opencode-tools commit-with-scope [-p] [-a|--auto-stage] [extra prompt...]`

Runs the `semantic-commit` skill and attaches any optional guidance you pass in.
 With `-a|--auto-stage`, runs `semantic-commit-autostage` instead.

Fallback:

- If `semantic-commit` skill is not installed (missing `$CODEX_HOME/skills/tools/devex/semantic-commit/SKILL.md`), the command falls back to a local interactive Conventional Commit flow (and `-p` still pushes).
- If `-a|--auto-stage` is set but `semantic-commit-autostage` is not installed (missing `$CODEX_HOME/skills/automation/semantic-commit-autostage/SKILL.md`), the command errors.

Options:

- `-p`: Push the committed changes to the remote repository.
- `-a`, `--auto-stage`: Use `semantic-commit-autostage` (autostage all changes) instead of `semantic-commit`.

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

| Env | Default | Options | Description |
| --- | --- | --- | --- |
| `OPENCODE_CLI_MODEL` | (unset) | any `opencode run -m` value | Forwarded to `opencode run -m`. |
| `OPENCODE_CLI_VARIANT` | (unset) | any `opencode run --variant` value | Forwarded to `opencode run --variant`. |
