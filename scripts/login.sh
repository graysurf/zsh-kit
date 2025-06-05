#!/bin/bash

# Prevent double execution
[[ -n "$_LOGIN_SH_EXECUTED" ]] && return
export _LOGIN_SH_EXECUTED=1

# Load emoji function from shared script
source "$ZDOTDIR/scripts/random_emoji.sh"
QUOTE_EMOJI="$(random_emoji)"

# Try to fetch quote from API
quote_json=$(curl -s --max-time 2 "https://zenquotes.io/api/random")

quote=$(echo "$quote_json" | jq -r '.[0].q' 2>/dev/null)
author=$(echo "$quote_json" | jq -r '.[0].a' 2>/dev/null)

# Fallback quote if needed
if [[ -z "$quote" || "$quote" == "null" || -z "$author" || "$author" == "null" ]]; then
  if [[ -f "$ZDOTDIR/assets/quotes.txt" ]]; then
    fallback_quote=$(shuf -n 1 "$ZDOTDIR/assets/quotes.txt")
    echo "📜 $fallback_quote"
  else
    echo "💬 \"Stay hungry, stay foolish.\" — Steve Jobs"
  fi
else
  echo "\n$QUOTE_EMOJI \"$quote\" — $author"
fi

echo
