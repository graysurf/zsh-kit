# ────────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    gcp gcpo gcapo gcapf gcapfo gcapff gcapffo \
    gpc gpcp gpcpf gpcpff gpcpo gpcpfo gpcpffo \
    gpca gpcap gpcapf gpcapff gpcapo gpcapfo gpcapffo
fi

# ────────────────────────────────────────────────────────
# Git magic: compound commit + push + GitHub open flows
# These aliases combine multiple actions into a single command.
# Notes:
# - Clipboard variants require `get_clipboard`.
# - Open variants require `git-open commit` (browser open).
# ────────────────────────────────────────────────────────

# gcp
# Commit staged changes, then push.
# Usage: gcp
# Safety:
# - Runs `git push` and may publish commits to the remote.
alias gcp='git commit && git push'

# gcap
# Amend the last commit, then push.
# Usage: gcap
# Safety:
# - `git commit --amend` rewrites the last commit; if already pushed, you may need force push.
alias gcap='git commit --amend && git push'

# gcpo
# Commit staged changes, push, and open `HEAD` commit in the browser.
# Usage: gcpo
# Safety:
# - Runs `git push` and may publish commits to the remote.
alias gcpo='git commit && git push && git-open commit HEAD'

# gcapo
# Amend the last commit, push, and open `HEAD` commit in the browser.
# Usage: gcapo
# Safety:
# - `git commit --amend` rewrites the last commit; if already pushed, you may need force push.
alias gcapo='git commit --amend && git push && git-open commit HEAD'

# gcapf
# Amend the last commit, then force-push with lease.
# Usage: gcapf
# Safety:
# - Rewrites remote history (`git push --force-with-lease`).
alias gcapf='git commit --amend && git push --force-with-lease'

# gcapfo
# Amend the last commit, force-push with lease, and open `HEAD` commit in the browser.
# Usage: gcapfo
# Safety:
# - Rewrites remote history (`git push --force-with-lease`).
alias gcapfo='git commit --amend && git push --force-with-lease && git-open commit HEAD'

# gcapff
# Amend the last commit, then force-push (DANGEROUS).
# Usage: gcapff
# Safety:
# - Overwrites remote history (`git push -f`).
alias gcapff='git commit --amend && git push -f'

# gcapffo
# Amend the last commit, force-push, and open `HEAD` commit in the browser (DANGEROUS).
# Usage: gcapffo
# Safety:
# - Overwrites remote history (`git push -f`).
alias gcapffo='git commit --amend && git push -f && git-open commit HEAD'

# gpc
# Commit staged changes using a commit message from clipboard.
# Usage: gpc
# Notes:
# - Requires `get_clipboard`.
alias gpc='git commit -F <(get_clipboard)'

# gpcp
# Commit using clipboard message, then push.
# Usage: gpcp
# Notes:
# - Requires `get_clipboard`.
# Safety:
# - Runs `git push` and may publish commits to the remote.
alias gpcp='git commit -F <(get_clipboard) && git push'

# gpcpf
# Commit using clipboard message, then force-push with lease.
# Usage: gpcpf
# Notes:
# - Requires `get_clipboard`.
# Safety:
# - Rewrites remote history (`git push --force-with-lease`).
alias gpcpf='git commit -F <(get_clipboard) && git push --force-with-lease'

# gpcpff
# Commit using clipboard message, then force-push (DANGEROUS).
# Usage: gpcpff
# Notes:
# - Requires `get_clipboard`.
# Safety:
# - Overwrites remote history (`git push -f`).
alias gpcpff='git commit -F <(get_clipboard) && git push -f'

# gpcpo
# Commit using clipboard message, push, and open `HEAD` commit in the browser.
# Usage: gpcpo
# Notes:
# - Requires `get_clipboard`.
# Safety:
# - Runs `git push` and may publish commits to the remote.
alias gpcpo='git commit -F <(get_clipboard) && git push && git-open commit HEAD'

# gpcpfo
# Commit using clipboard message, force-push with lease, and open `HEAD` commit in the browser.
# Usage: gpcpfo
# Notes:
# - Requires `get_clipboard`.
# Safety:
# - Rewrites remote history (`git push --force-with-lease`).
alias gpcpfo='git commit -F <(get_clipboard) && git push --force-with-lease && git-open commit HEAD'

# gpcpffo
# Commit using clipboard message, force-push, and open `HEAD` commit in the browser (DANGEROUS).
# Usage: gpcpffo
# Notes:
# - Requires `get_clipboard`.
# Safety:
# - Overwrites remote history (`git push -f`).
alias gpcpffo='git commit -F <(get_clipboard) && git push -f && git-open commit HEAD'

# gpca
# Amend the last commit message using clipboard content.
# Usage: gpca
# Notes:
# - Requires `get_clipboard`.
# Safety:
# - Rewrites the last commit; if already pushed, you may need force push.
alias gpca='git commit --amend -F <(get_clipboard)'

# gpcap
# Amend the last commit message using clipboard content, then push.
# Usage: gpcap
# Notes:
# - Requires `get_clipboard`.
# Safety:
# - Rewrites the last commit; if already pushed, you may need force push.
alias gpcap='git commit --amend -F <(get_clipboard) && git push'

# gpcapf
# Amend using clipboard content, then force-push with lease.
# Usage: gpcapf
# Notes:
# - Requires `get_clipboard`.
# Safety:
# - Rewrites remote history (`git push --force-with-lease`).
alias gpcapf='git commit --amend -F <(get_clipboard) && git push --force-with-lease'

# gpcapff
# Amend using clipboard content, then force-push (DANGEROUS).
# Usage: gpcapff
# Notes:
# - Requires `get_clipboard`.
# Safety:
# - Overwrites remote history (`git push -f`).
alias gpcapff='git commit --amend -F <(get_clipboard) && git push -f'

# gpcapo
# Amend using clipboard content, push, and open `HEAD` commit in the browser.
# Usage: gpcapo
# Notes:
# - Requires `get_clipboard`.
# Safety:
# - Rewrites the last commit; if already pushed, you may need force push.
alias gpcapo='git commit --amend -F <(get_clipboard) && git push && git-open commit HEAD'

# gpcapfo
# Amend using clipboard content, force-push with lease, and open `HEAD` commit in the browser.
# Usage: gpcapfo
# Notes:
# - Requires `get_clipboard`.
# Safety:
# - Rewrites remote history (`git push --force-with-lease`).
alias gpcapfo='git commit --amend -F <(get_clipboard) && git push --force-with-lease && git-open commit HEAD'

# gpcapffo
# Amend using clipboard content, force-push, and open `HEAD` commit in the browser (DANGEROUS).
# Usage: gpcapffo
# Notes:
# - Requires `get_clipboard`.
# Safety:
# - Overwrites remote history (`git push -f`).
alias gpcapffo='git commit --amend -F <(get_clipboard) && git push -f && git-open commit HEAD'
