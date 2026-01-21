# Feature: codex aliases
#
# Provides short, unambiguous aliases for codex helpers.
# - `cx`     -> `codex-tools`
# - `cxg*`   -> `codex-tools agent ...` (use `g` to avoid clashing with `auth`)
# - `cxa*`   -> `codex-tools auth ...`
# - `cxd*`   -> `codex-tools diag ...`
# - `cxc*`   -> `codex-tools config ...`
# - `crl*`   -> rate-limit helpers

if command -v safe_unalias >/dev/null; then
  safe_unalias \
    cx \
    cxgp cxga cxgk cxgc \
    cxau cxar cxaa cxac cxas \
    cxdr \
    cxcs cxct \
    crl crla
fi

# cx
# Alias of `codex-tools`.
# Usage: cx <command> [args...]
alias cx='codex-tools'

# ────────────────────────────────────────────────────────
# codex-tools agent (cxg*)
# ────────────────────────────────────────────────────────

# cxgp
# Alias of `codex-tools agent prompt`.
# Usage: cxgp [prompt...]
alias cxgp='codex-tools agent prompt'

# cxga
# Alias of `codex-tools agent advice`.
# Usage: cxga [question]
alias cxga='codex-tools agent advice'

# cxgk
# Alias of `codex-tools agent knowledge`.
# Usage: cxgk [concept]
alias cxgk='codex-tools agent knowledge'

# cxgc
# Alias of `codex-tools agent commit`.
# Usage: cxgc [args...]
alias cxgc='codex-tools agent commit'

# ────────────────────────────────────────────────────────
# codex-tools auth (cxa*)
# ────────────────────────────────────────────────────────

# cxau
# Alias of `codex-tools auth use`.
# Usage: cxau <profile|email>
alias cxau='codex-tools auth use'

# cxar
# Alias of `codex-tools auth refresh`.
# Usage: cxar [secret.json]
alias cxar='codex-tools auth refresh'

# cxaa
# Alias of `codex-tools auth auto-refresh`.
# Usage: cxaa
alias cxaa='codex-tools auth auto-refresh'

# cxac
# Alias of `codex-tools auth current`.
# Usage: cxac
alias cxac='codex-tools auth current'

# cxas
# Alias of `codex-tools auth sync`.
# Usage: cxas
alias cxas='codex-tools auth sync'

# ────────────────────────────────────────────────────────
# codex-tools diag (cxd*)
# ────────────────────────────────────────────────────────

# cxdr
# Alias of `codex-tools diag rate-limits`.
# Usage: cxdr [args...]
alias cxdr='codex-tools diag rate-limits'

# ────────────────────────────────────────────────────────
# codex-tools config (cxc*)
# ────────────────────────────────────────────────────────

# cxcs
# Alias of `codex-tools config show`.
# Usage: cxcs
alias cxcs='codex-tools config show'

# cxct
# Alias of `codex-tools config set`.
# Usage: cxct <key> <value>
alias cxct='codex-tools config set'

# ────────────────────────────────────────────────────────
# Rate limits helpers
# ────────────────────────────────────────────────────────

# crl
# Alias for `codex-rate-limits`.
# Usage: crl [args...]
alias crl='codex-rate-limits'

# crla
# Alias for `codex-rate-limits-async`.
# Usage: crla [args...]
alias crla='codex-rate-limits-async'
