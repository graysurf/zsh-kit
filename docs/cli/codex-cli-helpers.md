# Codex CLI helpers

This repo no longer ships the legacy Zsh implementation of `codex-tools`.
`codex-tools` is now expected to be provided by a **native binary** (Rust) installed on your `PATH`.

The remaining `codex` feature in this repo focuses on:

- secrets + auth helpers (e.g. `codex-use`, `codex-rate-limits`)
- `codex-starship` integration
- convenience aliases (e.g. `cx` → `codex-tools`)

## Legacy docs (archived)

- Archived documentation (historical reference): [`archive/legacy-zsh-cli-tools/docs/cli/codex-cli-helpers.md`](../../archive/legacy-zsh-cli-tools/docs/cli/codex-cli-helpers.md)
- Archived Zsh implementation: [`archive/legacy-zsh-cli-tools/scripts/_features/codex/codex-tools.zsh`](../../archive/legacy-zsh-cli-tools/scripts/_features/codex/codex-tools.zsh)
- Archived completion: [`archive/legacy-zsh-cli-tools/scripts/_features/codex/_completion/_codex-tools`](../../archive/legacy-zsh-cli-tools/scripts/_features/codex/_completion/_codex-tools)
