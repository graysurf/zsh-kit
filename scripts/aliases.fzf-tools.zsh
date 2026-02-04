# ────────────────────────────────────────────────────────
# fzf-tools aliases (native binary integration)
# ────────────────────────────────────────────────────────
# This repo no longer ships the Zsh implementation of `fzf-tools`.
# The command is expected to be provided by a native binary on `PATH`.

if command -v safe_unalias >/dev/null; then
  safe_unalias ft fgs gg fgc ff fv fp
fi

# ft
# Alias of `fzf-tools`.
# Usage: ft <subcommand> [args...]
alias ft='fzf-tools'

# fgs
# Alias of `fzf-tools git-status`.
# Usage: fgs [query]
alias fgs='fzf-tools git-status'

# gg
# Alias of `fzf-tools git-status`.
# Usage: gg [query]
alias gg='fzf-tools git-status'

# fgc
# Alias of `fzf-tools git-commit`.
# Usage: fgc [--snapshot] [query]
alias fgc='fzf-tools git-commit'

# ff
# Alias of `fzf-tools file`.
# Usage: ff [args...]
alias ff='fzf-tools file'

# fv
# Alias of `fzf-tools file --vscode`.
# Usage: fv [args...]
alias fv='fzf-tools file --vscode'

# fp
# Alias of `fzf-tools port`.
# Usage: fp [-k|--kill] [-9|--force] [query]
alias fp='fzf-tools port'

