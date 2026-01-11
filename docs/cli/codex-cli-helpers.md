# 🤖 Codex CLI Helpers: Opt-In Codex Skill Wrappers

This feature is disabled by default. Enable it by including `codex` in `ZSH_FEATURES` (e.g. in your home `~/.zshenv`).

`scripts/_features/codex/codex-tools.zsh` adds a `codex-tools` dispatcher plus four `codex-*` commands that invoke
Codex skills with a consistent, interactive CLI interface. The helpers are intentionally opt-in and only run when you
explicitly allow the dangerous sandbox bypass.

---

## 📦 Use Cases

- Generate a Semantic Commit message while including git-scope context
- Create a feature branch and PR from a short request prompt
- Triage and fix bugs using a guided skill workflow
- Run a structured release workflow with optional constraints

---

## 🛠 Commands

### `codex-tools <command> [args...]`

Dispatcher for the helpers below:

```bash
codex-tools commit-with-scope "Prefer terse subject lines"
```

---

### `codex-commit-with-scope [-p] [extra prompt...]`

Runs the `semantic-commit` skill and attaches any optional guidance you pass in.

Options:
- `-p`: Push the committed changes to the remote repository.

```bash
codex-commit-with-scope -p "Prefer terse subject lines"
```

---

### `codex-create-feature-pr [feature request...]`

Runs the `create-feature-pr` skill. If you omit the argument, it will prompt for a request.

```bash
codex-create-feature-pr "Add a new git-alias for cherry-pick workflows"
```

---

### `codex-find-and-fix-bugs [bug report...]`

Runs the `find-and-fix-bugs` skill. If you omit the argument, it will prompt for an optional report.

```bash
codex-find-and-fix-bugs "Investigate intermittent failure in plugin fetcher"
```

---

### `codex-release-workflow [release request...]`

Runs the `release-workflow` skill. If you omit the argument, it will prompt for optional context.

```bash
codex-release-workflow "Tag v2.3.0 and publish release notes"
```

---

## 🔐 Safety Gate

All helpers require `CODEX_ALLOW_DANGEROUS=true`. If it is not set, the helpers print a disabled
message and return non-zero.

```bash
CODEX_ALLOW_DANGEROUS=true codex-commit-with-scope "Use conventional scopes"
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
