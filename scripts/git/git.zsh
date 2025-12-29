# ────────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias \
    ga gaa gau gap \
    gu gup gwd \
    gd gc gca \
    gl gp gpf gpff \
    gpo gpfo gpffo \
    git-zip \
    lg lgr \
    gt gt2 gt3 gt5
fi

# ────────────────────────────────────────────────────────
# Git staging/unstaging shortcuts
# ────────────────────────────────────────────────────────

# ga
# Alias of `git add`.
# Usage: ga [args...]
alias ga='git add'

# gaa
# Alias of `git add -A` (stage all changes).
# Usage: gaa [args...]
alias gaa='git add -A'

# gau
# Alias of `git add -u` (stage tracked file changes).
# Usage: gau [args...]
alias gau='git add -u'

# gap
# Alias of `git add -p` (interactive staging).
# Usage: gap [args...]
alias gap='git add -p'

# gu
# Alias of `git restore --staged` (unstage; keep working tree).
# Usage: gu [args...]
alias gu='git restore --staged'

# gup
# Alias of `git restore --staged -p` (interactive unstage).
# Usage: gup [args...]
alias gup='git restore --staged -p'

# gwd
# Alias of `git restore --worktree` (DANGEROUS: discards local changes).
# Usage: gwd [args...]
# Safety:
# - This can overwrite tracked working-tree changes; verify with `git status` first.
alias gwd='git restore --worktree'

# ────────────────────────────────────────────────────────
# Git workflow aliases
# ────────────────────────────────────────────────────────

# gd
# Show staged diff and also write to the terminal (useful when piping/copying).
# Usage: gd
alias gd='git diff --cached --no-color | tee /dev/tty'

# gl
# Alias of `git pull`.
# Usage: gl [args...]
alias gl='git pull'

# gc
# Alias of `git commit`.
# Usage: gc [args...]
alias gc='git commit'

# gca
# Alias of `git commit --amend` (rewrites the last commit).
# Usage: gca [args...]
# Safety:
# - If the commit was pushed, amending requires force push and can affect others.
alias gca='git commit --amend'

# gp
# Alias of `git push`.
# Usage: gp [args...]
alias gp='git push'

# gpf
# Alias of `git push --force-with-lease` (safer force push).
# Usage: gpf [args...]
# Safety:
# - Still rewrites remote history; use only when you know it’s safe.
alias gpf='git push --force-with-lease'

# gpff
# Alias of `git push -f` (DANGEROUS: overwrites remote history).
# Usage: gpff [args...]
# Safety:
# - Prefer `gpf` unless you explicitly need unconditional force push.
alias gpff='git push -f'

# gpo
# Push current branch and open `HEAD` commit in the browser.
# Usage: gpo
# Notes:
# - Extra args are NOT forwarded to `git push` (they would go to `git-open commit`).
alias gpo='git push && git-open commit HEAD'

# gpfo
# Force-push with lease and open `HEAD` commit in the browser.
# Usage: gpfo
# Notes:
# - Extra args are NOT forwarded to `git push` (they would go to `git-open commit`).
alias gpfo='git push --force-with-lease && git-open commit HEAD'

# gpffo
# Force-push and open `HEAD` commit in the browser (DANGEROUS).
# Usage: gpffo
# Notes:
# - Extra args are NOT forwarded to `git push` (they would go to `git-open commit`).
# Safety:
# - Overwrites remote history; prefer `gpfo` unless you explicitly need `-f`.
alias gpffo='git push -f && git-open commit HEAD'

# ────────────────────────────────────────────────────────
# Git utility aliases
# ────────────────────────────────────────────────────────

# git-zip
# Export `HEAD` as a zip named by short hash (writes a file in the current directory).
# Usage: git-zip
alias git-zip='git archive --format zip HEAD -o "backup-$(git rev-parse --short HEAD).zip"'

# lg
# List files (long format) with Git status via `eza`.
# Usage: lg [args...]
alias lg='eza -alh --icons --group-directories-first --color=always --git --time-style=iso'

# lgr
# List directories with Git repo status indicators via `eza`.
# Usage: lgr [args...]
alias lgr='eza -alh --icons --group-directories-first --color=always --git --git-repos --time-style=iso'

# ────────────────────────────────────────────────────────
# Directory tree view aliases (with Git-aware listings)
# ────────────────────────────────────────────────────────

# git-tree [depth] [path...]
# Git-aware tree view using `eza`.
# Usage: git-tree [depth] [path...]
# Notes:
# - If the first argument is a number, it is treated as the depth (`eza --level`).
git-tree() {
  # If first argument is a number, treat it as depth (--level)
  local level_flag=()
  local first_arg="${1-}"
  if [[ "$first_arg" =~ ^[0-9]+$ ]]; then
    level_flag=(--level "$first_arg")
    shift
  fi
  eza -aT --git-ignore --group-directories-first --color=always --icons "${level_flag[@]}" "$@"
  return $?
}

# gt
# Alias of `git-tree`.
# Usage: gt [args...]
alias gt='git-tree'

# gt2
# Alias of `gt -L 2` (tree depth 2).
# Usage: gt2 [args...]
alias gt2='gt -L 2'

# gt3
# Alias of `gt -L 3` (tree depth 3).
# Usage: gt3 [args...]
alias gt3='gt -L 3'

# gt5
# Alias of `gt -L 5` (tree depth 5).
# Usage: gt5 [args...]
alias gt5='gt -L 5'
