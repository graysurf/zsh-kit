# ────────────────────────────────────────────────────────
# Git magic aliases (composite actions)
# ────────────────────────────────────────────────────────
safe_unalias \
  gcp gcpo gcapo gcapfo gcapffo \
  gpc gpcp gpcpo gpcpfo gpcpffo \
  gpca gpcap  gpcapf gpcapff \
  gpcapo gpcapfo gpcapffo \
  2>/dev/null

# ────────────────────────────────────────────────────────
# Git magic: compound commit + push + GitHub open flows
# These aliases combine multiple actions into automated flows.
# Requires: get_clipboard, gh CLI authenticated
# ────────────────────────────────────────────────────────

# Commit staged changes, then push
alias gcp='git commit && git push'
# Amend the last commit, then push
alias gcap='git commit --amend && git push'

# Commit staged changes, push, and open the commit on GitHub
alias gcpo='git commit && git push && gh-open-commit HEAD'
# Amend the last commit, push, and open on GitHub
alias gcapo='git commit --amend && git push && gh-open-commit HEAD'

# Amend the last commit, safely force-push
alias gcapf='git commit --amend && git push --force-with-lease'
# Amend the last commit, safely force-push, and open on GitHub (safer)
alias gcapfo='git commit --amend && git push --force-with-lease && gh-open-commit HEAD'
# Amend the last commit, force-push
alias gcapff='git commit --amend && git push -f'
# Amend the last commit, force-push, and open on GitHub (DANGEROUS)
alias gcapffo='git commit --amend && git push -f && gh-open-commit HEAD'

# Commit using clipboard message
alias gpc='git commit -F <(get_clipboard)'
# Commit using clipboard, then push
alias gpcp='git commit -F <(get_clipboard) && git push'
# Commit using clipboard, push, and open on GitHub
alias gpcpo='git commit -F <(get_clipboard) && git push && gh-open-commit HEAD'
# Commit using clipboard, safely force-push, and open on GitHub (safer)
alias gpcpfo='git commit -F <(get_clipboard) && git push --force-with-lease && gh-open-commit HEAD'
# Commit using clipboard, force-push, and open on GitHub (DANGEROUS)
alias gpcpffo='git commit -F <(get_clipboard) && git push -f && gh-open-commit HEAD'

# Amend commit using clipboard message
alias gpca='git commit --amend -F <(get_clipboard)'
# Amend using clipboard, push
alias gpcap='git commit --amend -F <(get_clipboard) && git push'
# Amend using clipboard, safely force-push (no open)
alias gpcapf='git commit --amend -F <(get_clipboard) && git push --force-with-lease'
# Amend using clipboard, force-push (DANGEROUS, no open)
alias gpcapff='git commit --amend -F <(get_clipboard) && git push -f'
# Amend using clipboard, push, and open on GitHub
alias gpcapo='git commit --amend -F <(get_clipboard) && git push && gh-open-commit HEAD'
# Amend using clipboard, safely force-push, and open on GitHub (safer)
alias gpcapfo='git commit --amend -F <(get_clipboard) && git push --force-with-lease && gh-open-commit HEAD'
# Amend using clipboard, force-push, and open on GitHub (DANGEROUS)
alias gpcapffo='git commit --amend -F <(get_clipboard) && git push -f && gh-open-commit HEAD'
