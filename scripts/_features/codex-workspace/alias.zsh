# Feature: codex-workspace aliases
#
# Provides short aliases for codex-workspace helpers.
# - `cw`   -> `codex-workspace`
# - `cw*`  -> `codex-workspace <subcommand> ...`
# - `cwa*` -> `codex-workspace auth ...`
# - `cwr*` -> `codex-workspace reset ...`

if command -v safe_unalias >/dev/null; then
  safe_unalias \
    cw \
    cwa cwac cwah cwag \
    cwc cwl cwe \
    cwr cwrr cwrw cwro cwrp \
    cwm cwt
fi

# cw
# Alias of `codex-workspace`.
# Usage: cw <subcommand> [args...]
alias cw='codex-workspace'

# ────────────────────────────────────────────────────────
# codex-workspace subcommands (cw*)
# ────────────────────────────────────────────────────────

# cwa
# Alias of `codex-workspace auth`.
# Usage: cwa <provider> [args...]
alias cwa='codex-workspace auth'

# cwac
# Alias of `codex-workspace auth codex`.
# Usage: cwac [args...]
alias cwac='codex-workspace auth codex'

# cwah
# Alias of `codex-workspace auth github`.
# Usage: cwah [args...]
alias cwah='codex-workspace auth github'

# cwag
# Alias of `codex-workspace auth gpg`.
# Usage: cwag [args...]
alias cwag='codex-workspace auth gpg'

# cwc
# Alias of `codex-workspace create`.
# Usage: cwc [args...]
alias cwc='codex-workspace create'

# cwl
# Alias of `codex-workspace ls`.
# Usage: cwl [args...]
alias cwl='codex-workspace ls'

# cwe
# Alias of `codex-workspace exec`.
# Usage: cwe [args...]
alias cwe='codex-workspace exec'

# cwr
# Alias of `codex-workspace reset`.
# Usage: cwr <command> [args...]
alias cwr='codex-workspace reset'

# cwrr
# Alias of `codex-workspace reset repo`.
# Usage: cwrr [args...]
alias cwrr='codex-workspace reset repo'

# cwrw
# Alias of `codex-workspace reset work-repos`.
# Usage: cwrw [args...]
alias cwrw='codex-workspace reset work-repos'

# cwro
# Alias of `codex-workspace reset opt-repos`.
# Usage: cwro [args...]
alias cwro='codex-workspace reset opt-repos'

# cwrp
# Alias of `codex-workspace reset private-repo`.
# Usage: cwrp [args...]
alias cwrp='codex-workspace reset private-repo'

# cwm
# Alias of `codex-workspace rm`.
# Usage: cwm [args...]
alias cwm='codex-workspace rm'

# cwt
# Alias of `codex-workspace tunnel`.
# Usage: cwt [args...]
alias cwt='codex-workspace tunnel'
