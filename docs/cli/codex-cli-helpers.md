# 🤖 Codex CLI Helpers: Opt-In Codex Skill Wrappers

This feature is disabled by default. Enable it by including `codex` in `ZSH_FEATURES` (e.g. in your home `~/.zshenv`).

`scripts/_features/codex/codex-tools.zsh` adds a `codex-tools` dispatcher plus several `codex-*` commands that invoke
Codex skills or prompts with a consistent, interactive CLI interface.
 The helpers are intentionally opt-in and only run when you
explicitly allow the dangerous sandbox bypass.

Prompt templates are shared under `$ZDOTDIR/prompts` (e.g. `prompts/actionable-advice.md`).

---

## 📦 Use Cases

- Generate a Semantic Commit message while including git-scope context
- Get explicit, actionable engineering advice based on a structured template
- Explore complex concepts with clear explanations and multiple analytical angles
- Refresh Codex authentication tokens manually
- Check Codex usage and rate limits across accounts

---

## 🛠 Commands

### `codex-tools <command> [args...]`

Dispatcher for the helpers below:

```bash
codex-tools commit-with-scope "Prefer terse subject lines"
```

Alias:

```bash
cx commit-with-scope "Prefer terse subject lines"
```

---

### `codex-tools <prompt...>` (raw prompt)

If the first argument is not a known command, `codex-tools` treats everything as a raw prompt:

```bash
codex-tools "advice about X"
```

To force raw prompt mode when your prompt starts with a command word, use `--` (or `prompt`):

```bash
codex-tools -- "advice about X"
codex-tools prompt "advice about X"
```

---

### `codex-tools commit-with-scope [-p] [-a|--auto-stage] [extra prompt...]`

Runs the `semantic-commit` skill and attaches any optional guidance you pass in. With `-a|--auto-stage`, runs `semantic-commit-autostage` instead.

Fallback:

- If `semantic-commit` skill is not installed (missing `$CODEX_HOME/skills/tools/devex/semantic-commit/SKILL.md`), the command falls back to a local interactive Conventional Commit flow (and `-p` still pushes).
- If `-a|--auto-stage` is set but `semantic-commit-autostage` is not installed (missing `$CODEX_HOME/skills/automation/semantic-commit-autostage/SKILL.md`), the command errors.

Options:

- `-p`: Push the committed changes to the remote repository.
- `-a`, `--auto-stage`: Use `semantic-commit-autostage` (autostage all changes) instead of `semantic-commit`.

```bash
codex-tools commit-with-scope -p "Prefer terse subject lines"
```

---

### `codex-tools advice [question...]`

Runs the `actionable-advice` prompt template. If you omit the argument, it will prompt for a question.

```bash
codex-tools advice "How to optimize Zsh startup time?"
```

---

### `codex-tools knowledge [concept...]`

Runs the `actionable-knowledge` prompt template. If you omit the argument, it will prompt for a concept.

```bash
codex-tools knowledge "What is a Closure in programming?"
```

---

### `codex-tools auto-refresh`

Runs the `auto-refresh` helper to refresh authentication tokens.

```bash
codex-tools auto-refresh
```

---

### `codex-tools rate-limits [options] [secret.json]`

Checks Codex usage and rate limits. Supports caching and multi-account queries.

Options:

- `-c`: Clear cache before querying.
- `--cached`: Use local cache only.
- `--all`: Query all configured accounts.

```bash
codex-tools rate-limits --all
```

---

## 🔐 Safety Gate

Commands that run `codex exec --dangerously-bypass-approvals-and-sandbox` require `CODEX_ALLOW_DANGEROUS=true`.
 If it is not set, those commands print a disabled message and return non-zero.

```bash
CODEX_ALLOW_DANGEROUS=true codex-tools commit-with-scope "Use conventional scopes"
```

The helpers call:

```text
codex exec --dangerously-bypass-approvals-and-sandbox -s workspace-write
```

Use them only when you trust the workflow and want to bypass Codex sandbox constraints.

---

## ⚙️ Configuration

- `CODEX_CLI_MODEL` (default: `gpt-5.1-codex-mini`)
- `CODEX_CLI_REASONING` (default: `medium`)
