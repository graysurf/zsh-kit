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
- Switch Codex profile (auth secrets) quickly
- Check Codex usage and rate limits across accounts

---

## 🛠 Commands

### `codex-tools <command> [args...]`

Dispatcher for the helpers below:

```bash
codex-tools agent commit "Prefer terse subject lines"
```

Alias:

```bash
cx agent commit "Prefer terse subject lines"
```

---

### Command Groups

`codex-tools` organizes commands into domains (with back-compat shortcuts):

- `agent`: prompts + skill wrappers that run `codex exec` (requires safety gate)
- `auth`: profile + token helpers (no `codex exec`)
- `diag`: diagnostics (no `codex exec`)
- `config`: show/set codex-tools config (current shell only)

---

### `codex-tools <prompt...>` (raw prompt)

If the first argument is not a known command, `codex-tools` treats everything as a raw prompt:

```bash
codex-tools "advice about X"
```

To force raw prompt mode when your prompt starts with a command word, use `--`:

```bash
codex-tools -- "advice about X"
```

---

### `codex-tools agent commit [-p] [-a|--auto-stage] [extra prompt...]`

Runs the `semantic-commit` skill and attaches any optional guidance you pass in. With `-a|--auto-stage`, runs `semantic-commit-autostage` instead.

Fallback:

- If `semantic-commit` skill is not installed (missing `$CODEX_HOME/skills/tools/devex/semantic-commit/SKILL.md`), the command falls back to a local interactive Conventional Commit flow (and `-p` still pushes).
- If `-a|--auto-stage` is set but `semantic-commit-autostage` is not installed (missing `$CODEX_HOME/skills/automation/semantic-commit-autostage/SKILL.md`), the command errors.

Options:

- `-p`: Push the committed changes to the remote repository.
- `-a`, `--auto-stage`: Use `semantic-commit-autostage` (autostage all changes) instead of `semantic-commit`.

```bash
codex-tools agent commit -p "Prefer terse subject lines"
```

---

### `codex-tools agent advice [question...]`

Runs the `actionable-advice` prompt template. If you omit the argument, it will prompt for a question.

```bash
codex-tools agent advice "How to optimize Zsh startup time?"
```

---

### `codex-tools agent knowledge [concept...]`

Runs the `actionable-knowledge` prompt template. If you omit the argument, it will prompt for a concept.

```bash
codex-tools agent knowledge "What is a Closure in programming?"
```

---

### `codex-tools auth use <profile|email>`

Switches `CODEX_AUTH_FILE` to a secret under `CODEX_SECRET_DIR` (same behavior as `codex-use`).

Examples:

```bash
codex-tools auth use work
codex-tools auth use work.json
codex-tools auth use you@example.com
```

---

### `codex-tools auth refresh [secret.json]`

Refreshes OAuth tokens via `refresh_token`. Defaults to the active `CODEX_AUTH_FILE` (same behavior as `codex-refresh-auth`).

```bash
codex-tools auth refresh
codex-tools auth refresh work.json
```

---

### `codex-tools auth current`

Shows which secret matches the current `CODEX_AUTH_FILE`.

```bash
codex-tools auth current
```

---

### `codex-tools auth sync`

Syncs the current `CODEX_AUTH_FILE` back into any matching secret(s) under `CODEX_SECRET_DIR`.

```bash
codex-tools auth sync
```

---

### `codex-tools auth auto-refresh`

Runs the `auto-refresh` helper to refresh authentication tokens.

```bash
codex-tools auth auto-refresh
```

---

### `codex-tools diag rate-limits [options] [secret.json]`

Checks Codex usage and rate limits. Supports caching, multiple output modes, and multi-account queries (sync or async).

Options:

- `-c`: Clear codex-starship cache before querying.
- `--cached`: Use codex-starship cache only (no network).
- `--no-refresh-auth`: Do not refresh auth tokens on HTTP 401 (no retry).
- `-d`, `--debug`: Keep stderr and show per-account errors (for `--all` / `--async`).
- `--json`: Print raw wham/usage JSON (single account only).
- `--one-line`: Print a single-line summary (single account only).
- `--all`: Query all secrets under `CODEX_SECRET_DIR` (sync).
- `--async`: Query all secrets under `CODEX_SECRET_DIR` concurrently (`codex-rate-limits-async`).
- `-j`, `--jobs N`: Max concurrent requests (with `--async`, default: 5).

Notes:

- `--async` does not accept positional `secret.json` and does not support `--json` / `--one-line`.
- `--async` falls back to cached per-account output when a network request fails (use `--debug` to see captured stderr).
- The Name column always uses the secret profile filename (basename of the secret JSON).
- When printing to a TTY, percent cells are ANSI-colored by default; set `NO_COLOR=1` to disable colors.

```bash
codex-tools diag rate-limits --all
codex-tools diag rate-limits --async --jobs 10
NO_COLOR=1 codex-tools diag rate-limits --async --cached
```

---

### `codex-tools config show`

Prints current codex-tools settings.

```bash
codex-tools config show
```

---

### `codex-tools config set <key> <value>`

Sets a codex-tools setting in the current shell (no files are written).

Keys:

- `model` (sets `CODEX_CLI_MODEL`)
- `reasoning` (sets `CODEX_CLI_REASONING`)
- `dangerous` (sets `CODEX_ALLOW_DANGEROUS_ENABLED` to `true|false`)

```bash
codex-tools config set model gpt-5.1-codex-mini
codex-tools config set reasoning medium
codex-tools config set dangerous true
```

---

## 🔐 Safety Gate

Agent commands that run `codex exec --dangerously-bypass-approvals-and-sandbox` require `CODEX_ALLOW_DANGEROUS_ENABLED=true`.
If it is not set, those commands print a disabled message and return non-zero.

```bash
CODEX_ALLOW_DANGEROUS_ENABLED=true codex-tools agent commit "Use conventional scopes"
```

The helpers call:

```text
codex exec --dangerously-bypass-approvals-and-sandbox -s workspace-write
```

Use them only when you trust the workflow and want to bypass Codex sandbox constraints.

---

## ⚙️ Configuration

| Env | Default | Options | Description |
| --- | --- | --- | --- |
| `CODEX_CLI_MODEL` | `gpt-5.1-codex-mini` | any `codex exec -m` value | Model passed to `codex exec -m`. |
| `CODEX_CLI_REASONING` | `medium` | e.g. `low|medium\|high` \| Forwarded as `model_reasoning_effort`. |
