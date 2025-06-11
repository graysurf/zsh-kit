# ────────────────────────────────────────────────────────
# Unalias to avoid redefinition
# ────────────────────────────────────────────────────────
safe_unalias gd gc gca gl gp gpf gpff gpo gpfo gpffo \
        git-zip \
        lg lgr gt gt2 gt3 gt5 2>/dev/null

# ────────────────────────────────────────────────────────
# Git basic workflow aliases
# ────────────────────────────────────────────────────────

# Show staged changes and write to screen (for commit preview)
alias gd='git diff --cached --no-color | tee /dev/tty'

# Pull latest changes from remote
alias gl='git pull'

# Commit current staged changes
alias gc='git commit'
# Amend the last commit (edit message or add staged changes)
alias gca='git commit --amend'

# Push local commits to the remote (safe default)
alias gp='git push'
# Force-push with lease: ensures no one has pushed in the meantime (safer than -f)
alias gpf='git push --force-with-lease'
# Force-push unconditionally (DANGEROUS: may overwrite remote history)
alias gpff='git push -f'

# Push and open latest commit on GitHub
alias gpo='git push && gh-open-commit HEAD'
# Force-push with lease and open latest commit on GitHub (safe force)
alias gpfo='git push --force-with-lease && gh-open-commit HEAD'
# Force-push unconditionally and open latest commit on GitHub (DANGEROUS)
alias gpffo='git push -f && gh-open-commit HEAD'

# ────────────────────────────────────────────────────────
# Git utility aliases
# ────────────────────────────────────────────────────────

# Export current HEAD as zip file named by short hash (e.g. backup-a1b2c3d.zip)
alias git-zip='git archive --format zip HEAD -o "backup-$(git rev-parse --short HEAD).zip"'

# List all files with Git status in detailed view
alias lg='eza -alh --icons --group-directories-first --color=always --git --time-style=iso'
# List directories with Git repo status indicators
alias lgr='eza -alh --icons --group-directories-first --color=always --git --git-repos --time-style=iso'

# ────────────────────────────────────────────────────────
# Directory tree view aliases (with Git-aware listings)
# ────────────────────────────────────────────────────────

# Visual tree view of current directory (depth = unlimited)
alias gt='eza -aT --git-ignore --group-directories-first --color=always --icons'
# Tree view limited to depth 2 (e.g. folders + their subfolders)
alias gt2='gt -L 2'
# Tree view limited to depth 3 (folders + 2 sub-levels)
alias gt3='gt -L 3'
# Tree view limited to depth 5 (for inspecting deeper structures)
alias gt5='gt -L 5'
