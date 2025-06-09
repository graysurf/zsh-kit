# ────────────────────────────────────────────────────────
# git-summary: author-based contribution report
# Usage: git-summary "2024-01-01" "2024-12-31"
# Supports macOS and Linux with timezone correction (UTC+8)
# ────────────────────────────────────────────────────────

# Generate a contribution summary by author over a given date range.
# Accepts two parameters: start date and end date (YYYY-MM-DD).
_git_summary() {
  local since_param="$1"
  local until_param="$2"
  local log_args=()

  if [[ -z "$since_param" && -z "$until_param" ]]; then
    log_args=(--no-merges)
  else
    local tz_offset_hours=8
    local since_utc until_utc

    if [[ "$(uname)" == "Darwin" ]]; then
      since_utc=$(date -j -f "%Y-%m-%d" -v0H -v0M -v0S -v -"${tz_offset_hours}"H "$since_param" +"%Y-%m-%dT%H:%M:%S")
      until_utc=$(date -j -f "%Y-%m-%d" -v23H -v59M -v59S -v -"${tz_offset_hours}"H "$until_param" +"%Y-%m-%dT%H:%M:%S")
    else
      since_utc=$(date -d "$since_param 00:00:00 -${tz_offset_hours} hours" +"%Y-%m-%dT%H:%M:%S")
      until_utc=$(date -d "$until_param 23:59:59 -${tz_offset_hours} hours" +"%Y-%m-%dT%H:%M:%S")
    fi

    log_args+=(--since="$since_utc" --until="$until_utc" --no-merges)
  fi

  git log "${log_args[@]}" --pretty=format:"%an <%ae>" |
    sort | uniq | while read -r author; do
      email=$(echo "$author" | grep -oE "<.*>" | tr -d "<>")
      name=$(echo "$author" | sed -E "s/ <.*>//")
      short_email=$(printf "%.40s" "$email")

      added=$(git log "${log_args[@]}" --author="$email" --pretty=tformat: --numstat |
        grep -vE '\s+(yarn\.lock|package-lock\.json|pnpm-lock\.yaml|\.lock)$' |
        awk '{ add += $1 } END { print add }')

      deleted=$(git log "${log_args[@]}" --author="$email" --pretty=tformat: --numstat |
        grep -vE '\s+(yarn\.lock|package-lock\.json|pnpm-lock\.yaml|\.lock)$' |
        awk '{ del += $2 } END { print del }')

      commits=$(git log "${log_args[@]}" --author="$email" --pretty=oneline | wc -l)
      first_commit=$(git log "${log_args[@]}" --author="$email" --reverse --pretty=format:"%ad" --date=short | head -n1)
      last_commit=$(git log "${log_args[@]}" --author="$email" --pretty=format:"%ad" --date=short | head -n1)

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

# Show a summary of today's commits (local timezone).
_git_today() {
  local today=$(date +"%Y-%m-%d")
  echo -e "\n📅 Git summary for today: $today"
  echo
  _git_summary "$today" "$today"
}

# Show a summary of yesterday's commits (cross-platform).
_git_yesterday() {
  local yesterday
  if [[ "$(uname)" == "Darwin" ]]; then
    yesterday=$(date -v -1d +"%Y-%m-%d")
  else
    yesterday=$(date -d "yesterday" +"%Y-%m-%d")
  fi
  echo -e "\n📅 Git summary for yesterday: $yesterday"
  echo
  _git_summary "$yesterday" "$yesterday"
}

# Show a summary from the first day of the month to today.
_git_this_month() {
  local today=$(date +"%Y-%m-%d")
  local start_date=$(date +"%Y-%m-01")
  echo -e "\n📅 Git summary for this month: $start_date to $today"
  echo
  _git_summary "$start_date" "$today"
}

# Show a summary for the last full week (Monday to Sunday).
_git_last_week() {
  local CURRENT_DATE WEEKDAY START_DATE END_DATE
  CURRENT_DATE=$(date +"%Y-%m-%d")

  if [[ "$(uname)" == "Darwin" ]]; then
    WEEKDAY=$(date -j -f "%Y-%m-%d" "$CURRENT_DATE" +%u)
    END_DATE=$(date -j -f "%Y-%m-%d" -v -"$WEEKDAY"d "$CURRENT_DATE" +%Y-%m-%d)
    START_DATE=$(date -j -f "%Y-%m-%d" -v -6d "$END_DATE" +%Y-%m-%d)
  else
    WEEKDAY=$(date -d "$CURRENT_DATE" +%u)
    END_DATE=$(date -d "$CURRENT_DATE -$WEEKDAY days" +%Y-%m-%d)
    START_DATE=$(date -d "$END_DATE -6 days" +%Y-%m-%d)
  fi

  echo -e "\n📅 Git summary for last week: $START_DATE to $END_DATE"
  echo
  _git_summary "$START_DATE" "$END_DATE"
}

# Show a summary for the current week (Monday to Sunday).
_git_weekly() {
  local CURRENT_DATE WEEKDAY START_DATE END_DATE
  CURRENT_DATE=$(date +"%Y-%m-%d")

  if [[ "$(uname)" == "Darwin" ]]; then
    WEEKDAY=$(date -j -f "%Y-%m-%d" "$CURRENT_DATE" +%u)
    START_DATE=$(date -j -f "%Y-%m-%d" -v -"$((WEEKDAY - 1))"d "$CURRENT_DATE" +%Y-%m-%d)
    END_DATE=$(date -j -f "%Y-%m-%d" -v +"$((7 - WEEKDAY))"d "$CURRENT_DATE" +%Y-%m-%d)
  else
    WEEKDAY=$(date -d "$CURRENT_DATE" +%u)
    START_DATE=$(date -d "$CURRENT_DATE -$((WEEKDAY - 1)) days" +%Y-%m-%d)
    END_DATE=$(date -d "$START_DATE +6 days" +%Y-%m-%d)
  fi

  echo -e "\n📅 Git summary for this week: $START_DATE to $END_DATE"
  echo
  _git_summary "$START_DATE" "$END_DATE"
}

# CLI entry for git-summary.
# Supports:
# - Preset ranges (today, yesterday, this-month, etc.)
# - Custom date ranges: git-summary <start> <end>
# - Full history: git-summary all
git-summary() {
  case "$1" in
    all)
      echo -e "\n📅 Git summary for all commits"
      echo
      _git_summary
      ;;
    today)
      _git_today
      ;;
    yesterday)
      _git_yesterday
      ;;
    this-month)
      _git_this_month
      ;;
    last-week)
      _git_last_week
      ;;
    weekly)
      _git_weekly
      ;;
    ""|help|--help|-h)
      echo "Usage:"
      echo "  git-summary all                   # Entire history"
      echo "  git-summary <from> <to>           # Custom date range"
      echo "  git-summary today                 # Today only"
      echo "  git-summary yesterday             # Yesterday only"
      echo "  git-summary this-month            # 1st to today"
      echo "  git-summary last-week             # Last Mon–Sun"
      echo "  git-summary weekly                # This Mon–Sun"
      return 1
      ;;
    *)
      if [[ -n "$1" && -n "$2" ]]; then
        _git_summary "$1" "$2"
      else
        echo "❌ Invalid usage. Try: git-summary help"
        return 1
      fi
      ;;
  esac
}
