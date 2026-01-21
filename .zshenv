# ──────────────────────────────
# Zsh environment (always loaded)
# ──────────────────────────────

# Why this exists even if `.zshrc`/`.zprofile` also define paths:
# - `.zshenv` is loaded for non-interactive shells (e.g. `zsh -c ...`) where `.zshrc`/`.zprofile`
#   may not run. Keeping core `ZSH_*` exports here makes paths available everywhere.
# - Keep this file minimal + silent (exports only). Any init work belongs in `paths.init.zsh`.
#
# Note on `ZDOTDIR`:
# - Zsh chooses which `.zshenv` to load *before* it executes any user code, so setting `ZDOTDIR`
#   inside `~/.zshenv` won’t automatically make Zsh load `$ZDOTDIR/.zshenv`.
# - The recommended setup is: keep a tiny `~/.zshenv` that exports `ZDOTDIR="$HOME/.config/zsh"`
#   and then explicitly sources `$ZDOTDIR/.zshenv`. See `docs/guides/startup-files.md`.

[[ -r "${ZDOTDIR:-$HOME/.config/zsh}/scripts/_internal/paths.exports.zsh" ]] && \
  source "${ZDOTDIR:-$HOME/.config/zsh}/scripts/_internal/paths.exports.zsh"
