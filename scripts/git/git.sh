# ────────────────────────────────────────────────────────
# Unalias to avoid redefinition
# ────────────────────────────────────────────────────────
unalias \
  # Core Git workflow
  gd gc gca gl gp gpf gpff \
  \
  # Commit-push automation
  gcp gcpo gcapo gcapfo gcapffo \
  \
  # Clipboard-based commit flow
  gpc gpcp gpcpo gpca gpcapo gpcapfo gpcapffo \
  \
  # Git utility tools
  git-zip \
  \
  # Git-enhanced directory views
  lg lgr gt gt2 gt3 gt5 \
  \
  # Git summary functions
  git-summary git-today git-yesterday git-this-month git-last-week git-weekly \
  2>/dev/null

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

# ────────────────────────────────────────────────────────
# Git commit-push automation
# ────────────────────────────────────────────────────────

# Commit staged changes, push
alias gcp='git commit && git push'
# Commit staged changes, push, and open the commit on GitHub
alias gcpo='git commit && git push && gh-open-commit HEAD'

# Amend the last commit, push, and open the new commit on GitHub
alias gcapo='git commit --amend && git push && gh-open-commit HEAD'
# Amend the last commit, safely force-push, and open the new commit on GitHub (safer alternative)
alias gcapfo='git commit --amend && git push --force-with-lease && gh-open-commit HEAD'
# Amend the last commit, force-push, and open the new commit on GitHub (DANGEROUS)
alias gcapffo='git commit --amend && git push -f && gh-open-commit HEAD'

# ────────────────────────────────────────────────────────
# Git clipboard-based commit flow
# ────────────────────────────────────────────────────────

# Commit staged changes using commit message from clipboard
alias gpc='git commit -F <(pbpaste)'
# Commit using clipboard message, then push
alias gpcp='git commit -F <(pbpaste) && git push'
# Commit using clipboard message, push, and open the commit on GitHub
alias gpcpo='git commit -F <(pbpaste) && git push && gh-open-commit HEAD'

# Amend the last commit using commit message from clipboard
alias gpca='git commit --amend -F <(pbpaste)'
# Amend commit using clipboard message, then push
alias gpcapo='git commit --amend -F <(pbpaste) && git push && gh-open-commit HEAD'
# Amend commit using clipboard message, safely force-push, then open on GitHub
alias gpcapfo='git commit --amend -F <(pbpaste) && git push --force-with-lease && gh-open-commit HEAD'
# Amend commit using clipboard message, force-push, and open on GitHub (DANGEROUS)
alias gpcapffo='git commit --amend -F <(pbpaste) && git push -f && gh-open-commit HEAD'


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


# ────────────────────────────────────────────────────────
# git-summary: author-based contribution report
# Usage: git-summary "2024-01-01" "2024-12-31"
# ────────────────────────────────────────────────────────

git-summary() {
  since_param="$1"
  until_param="$2"

  since_opt=""
  until_opt=""

  [[ -n "$since_param" ]] && since_opt="--since=\"$since_param\""
  [[ -n "$until_param" ]] && until_opt="--until=\"$until_param\""

  git log $since_opt $until_opt --no-merges --pretty=format:"%an <%ae>" |
    sort | uniq | while read -r author; do
      email=$(echo "$author" | grep -oE "<.*>" | tr -d "<>")
      name=$(echo "$author" | sed -E "s/ <.*>//")
      short_email=$(printf "%.40s" "$email")

      added=$(eval git log $since_opt $until_opt --no-merges --author=\"$email\" --pretty=tformat: --numstat |
        grep -vE '\s+(yarn\.lock|package-lock\.json|pnpm-lock\.yaml|\.lock)$' |
        awk '{ add += $1 } END { print add }')

      deleted=$(eval git log $since_opt $until_opt --no-merges --author=\"$email\" --pretty=tformat: --numstat |
        grep -vE '\s+(yarn\.lock|package-lock\.json|pnpm-lock\.yaml|\.lock)$' |
        awk '{ del += $2 } END { print del }')

      commits=$(eval git log $since_opt $until_opt --no-merges --author=\"$email\" --pretty=oneline | wc -l)
      first_commit=$(eval git log $since_opt $until_opt --no-merges --author=\"$email\" --reverse --pretty=format:"%ad" --date=short | head -n1)
      last_commit=$(eval git log $since_opt $until_opt --no-merges --author=\"$email\" --pretty=format:"%ad" --date=short | head -n1)

      printf "%-25s %-40s %8s %8s %8s %8s %12s %12s\n" \
        "$name" "$short_email" "$added" "$deleted" "$((added - deleted))" "$commits" "$first_commit" "$last_commit"
    done | sort -k5 -nr | awk '
      BEGIN {
        printf "%-25s %-40s %8s %8s %8s %8s %12s %12s\n", "Name", "Email", "Added", "Deleted", "Net", "Commits", "First", "Last"
        print  "----------------------------------------------------------------------------------------------------------------------------------------"
      }
      { print }
    '
}

# git-today: show today's summary
git-today() {
  local today
  today=$(date -u +"%Y-%m-%d")
  echo -e "\n📅 Git summary for today: $today"
  echo
  git-summary "$today" "$today"
}

# git-yesterday: show yesterday's summary
git-yesterday() {
  local yesterday
  if [[ "$(uname)" == "Darwin" ]]; then
    yesterday=$(date -u -v -1d +"%Y-%m-%d")
  else
    yesterday=$(date -u -d "yesterday" +"%Y-%m-%d")
  fi
  echo -e "\n📅 Git summary for yesterday: $yesterday"
  echo
  git-summary "$yesterday" "$yesterday"
}

# git-this-month: from 1st of this month to today
git-this-month() {
  local start_date today
  today=$(date -u +"%Y-%m-%d")
  start_date=$(date -u +"%Y-%m-01")
  echo -e "\n📅 Git summary for this month: $start_date to $today"
  echo
  git-summary "$start_date" "$today"
}

# git-last-week: previous Monday to previous Sunday
git-last-week() {
  local CURRENT_DATE WEEKDAY START_DATE END_DATE
  local is_macos=false
  [[ "$(uname)" == "Darwin" ]] && is_macos=true

  if $is_macos; then
    CURRENT_DATE=$(date -u +"%Y-%m-%d")
    WEEKDAY=$(date -j -f "%Y-%m-%d" "$CURRENT_DATE" +%u)
    END_DATE=$(date -j -f "%Y-%m-%d" -v -"$WEEKDAY"d "$CURRENT_DATE" +%Y-%m-%d)
    START_DATE=$(date -j -f "%Y-%m-%d" -v -6d "$END_DATE" +%Y-%m-%d)
  else
    CURRENT_DATE=$(date -u +"%Y-%m-%d")
    WEEKDAY=$(date -u -d "$CURRENT_DATE" +%u)
    END_DATE=$(date -u -d "$CURRENT_DATE -$WEEKDAY days" +%Y-%m-%d)
    START_DATE=$(date -u -d "$END_DATE -6 days" +%Y-%m-%d)
  fi

  echo -e "\n📅 Git summary for last week: $START_DATE to $END_DATE"
  echo
  git-summary "$START_DATE" "$END_DATE"
}

# git-weekly: current week (Monday to Sunday)
git-weekly() {
  local CURRENT_DATE WEEKDAY START_DATE END_DATE
  local is_macos=false
  [[ "$(uname)" == "Darwin" ]] && is_macos=true

  if $is_macos; then
    CURRENT_DATE=$(date -u +"%Y-%m-%d")
    WEEKDAY=$(date -j -f "%Y-%m-%d" "$CURRENT_DATE" +%u)
    START_DATE=$(date -j -f "%Y-%m-%d" -v -"$((WEEKDAY - 1))"d "$CURRENT_DATE" +%Y-%m-%d)
    END_DATE=$(date -j -f "%Y-%m-%d" -v +"$((7 - WEEKDAY))"d "$CURRENT_DATE" +%Y-%m-%d)
  else
    CURRENT_DATE=$(date -u +"%Y-%m-%d")
    WEEKDAY=$(date -u -d "$CURRENT_DATE" +%u)
    START_DATE=$(date -u -d "$CURRENT_DATE -$((WEEKDAY - 1)) days" +%Y-%m-%d)
    END_DATE=$(date -u -d "$START_DATE +6 days" +%Y-%m-%d)
  fi

  echo -e "\n  Git summary for this week: $START_DATE to $END_DATE"
  echo
  git-summary "$START_DATE" "$END_DATE"
}
