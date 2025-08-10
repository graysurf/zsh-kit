# ────────────────────────────────────────────────────────
# git-summary: author-based contribution report
# Usage: git-summary "2024-01-01" "2024-12-31"
# Supports macOS and Linux with timezone correction based on system settings
# ───────────────────────────────────────────────────────


# ───────────────────────────────────────────────────────
# Aliases and Unalias
# ────────────────────────────────────────────────────────
if command -v safe_unalias >/dev/null; then
  safe_unalias _git_summary
fi

# Generate a contribution summary by author over a given date range.
# Accepts two parameters: start date and end date (YYYY-MM-DD).
_git_summary() {
  typeset since_param="$1"
  typeset until_param="$2"
  typeset log_args=()

  # Validate date parameters: either both empty (full history) or both provided
  if { [[ -n "$since_param" && -z "$until_param" ]] || [[ -z "$since_param" && -n "$until_param" ]] ; }; then
    echo "❌ Please provide both start and end dates (YYYY-MM-DD)."
    return 1
  fi

  if [[ -z "$since_param" && -z "$until_param" ]]; then
    log_args=(--no-merges)
  else
    # Use local calendar boundaries with explicit timezone, so Git parses them in local time.
    typeset tz_raw="$(date +%z)" # e.g., +0800
    typeset since_bound="$since_param 00:00:00 $tz_raw"
    typeset until_bound="$until_param 23:59:59 $tz_raw"
    log_args+=(--since="$since_bound" --until="$until_bound" --no-merges)
  fi

  git log "${log_args[@]}" --pretty=format:"%an <%ae>" |
    sort | uniq | while read -r author; do
      email=$(echo "$author" | grep -oE "<.*>" | tr -d "<>")
      name=$(echo "$author" | sed -E "s/ <.*>//")
      short_email=$(printf "%.40s" "$email")

      log=$(git log "${log_args[@]}" --author="$email" --pretty=format:'%cd' --date=short --numstat)
      filtered=$(echo "$log" | grep -vE '(yarn\.lock|package-lock\.json|pnpm-lock\.yaml|\.lock)$')

      added=$(echo "$filtered" | awk 'NF==3 { add += $1 } END { print add+0 }')
      deleted=$(echo "$filtered" | awk 'NF==3 { del += $2 } END { print del+0 }')
      commits=$(echo "$log" | awk 'NF==1 { c++ } END { print c+0 }')
      first_commit=$(echo "$log" | awk 'NF==1 { date=$1 } END { print date }')
      last_commit=$(echo "$log" | awk 'NF==1 { print $1; exit }')

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
  typeset today=$(date +"%Y-%m-%d")
  echo -e "\n📅 Git summary for today: $today"
  echo
  _git_summary "$today" "$today"
}

# Show a summary of yesterday's commits (cross-platform).
_git_yesterday() {
  typeset yesterday
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
  typeset today=$(date +"%Y-%m-%d")
  typeset start_date=$(date +"%Y-%m-01")
  echo -e "\n📅 Git summary for this month: $start_date to $today"
  echo
  _git_summary "$start_date" "$today"
}

# Show a summary for the last full month.
_git_last_month() {
  typeset start_date end_date

  if [[ "$(uname)" == "Darwin" ]]; then
    start_date=$(date -j -v-1m -v1d +"%Y-%m-%d")
    end_date=$(date -j -v1d -v-1d +"%Y-%m-%d")
  else
    start_date=$(date -d "$(date +%Y-%m-01) -1 month" +"%Y-%m-%d")
    end_date=$(date -d "$(date +%Y-%m-01) -1 day" +"%Y-%m-%d")
  fi

  echo -e "\n📅 Git summary for last month: $start_date to $end_date"
  echo
  _git_summary "$start_date" "$end_date"
}


# Show a summary for the last full week (Monday to Sunday).
_git_last_week() {
  typeset CURRENT_DATE WEEKDAY START_DATE END_DATE
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

# Show a summary for this week (Monday to Sunday).
_git_this_week() {
  typeset CURRENT_DATE WEEKDAY START_DATE END_DATE
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
    last-month)
      _git_last_month
      ;;
    this-week)
      _git_this_week
      ;;
    last-week)
      _git_last_week
      ;;
    ""|help|--help|-h)
      echo "Usage:"
      echo "  git-summary all            Entire history"
      echo "  git-summary <from> <to>    Custom date range"
      echo "  git-summary today          Today only"
      echo "  git-summary yesterday      Yesterday only"
      echo "  git-summary this-month     1st to today"
      echo "  git-summary last-month     1st to end of last month"
      echo "  git-summary this-week      This Mon–Sun"
      echo "  git-summary last-week      Last Mon–Sun"
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


