# ────────────────────────────────────────────────────────
# Unalias to avoid redefinition
# ────────────────────────────────────────────────────────
unalias gd gc gl gp gr git-zip \
        lg lgr \
        gt gt2 gt3 gt5 \
        git-summary git-today git-yesterday \
        git-this-month git-last-week git-weekly 2>/dev/null

# ────────────────────────────────────────────────────────
# Git-related aliases
# ────────────────────────────────────────────────────────

# Show staged changes and write to screen (for commit preview)
alias gd='git diff --cached --no-color | tee /dev/tty'

# Commit current staged changes
alias gc='git commit'
# Pull latest changes from remote
alias gl='git pull'
# Push local commits to remote
alias gp='git push'
# Rebase current branch onto another
alias gr='git rebase'

# Export current HEAD as zip file named by short hash (e.g. backup-a1b2c3d.zip)
alias git-zip='git archive --format zip HEAD -o "backup-$(git rev-parse --short HEAD).zip"'

# List all files with Git status in detailed view
alias lg='eza -alh --icons --group-directories-first --git --time-style=iso'
# List directories with Git repo status indicators
alias lgr='eza -alh --icons --group-directories-first --git --git-repos --time-style=iso'

# Visual tree view of current directory (depth = unlimited)
alias gt='eza -T --git-ignore --color=always --icons'
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
