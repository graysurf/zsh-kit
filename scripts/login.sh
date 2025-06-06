#!/bin/bash

# Prevent double execution
[[ -n "$_LOGIN_SH_EXECUTED" ]] && return
export _LOGIN_SH_EXECUTED=1

# Load emoji function
source "$ZDOTDIR/scripts/random_emoji.sh"
QUOTE_EMOJI="$(random_emoji)"

# Quote storage path
QUOTES_FILE="$ZDOTDIR/assets/quotes.txt"

if [[ -f "$QUOTES_FILE" && -s "$QUOTES_FILE" ]]; then
  quote_line=$(shuf -n 1 "$QUOTES_FILE")
  echo -e "\n📜 $quote_line"
else
  echo "💬 \"Stay hungry, stay foolish.\" — Steve Jobs"
fi

(
  nohup bash -c '
    quote_json=$(curl -s --max-time 2 "https://zenquotes.io/api/random")
    quote=$(echo "$quote_json" | jq -r ".[0].q" 2>/dev/null)
    author=$(echo "$quote_json" | jq -r ".[0].a" 2>/dev/null)

    if [[ -n "$quote" && "$quote" != "null" && -n "$author" && "$author" != "null" ]]; then
      echo "\"$quote\" — $author" >> "'"$QUOTES_FILE"'"
      tail -n 100 "'"$QUOTES_FILE"'" > "'"$QUOTES_FILE"'.tmp" && \
        mv "'"$QUOTES_FILE"'.tmp" "'"$QUOTES_FILE"'"
    fi
  ' &> /dev/null &
) >/dev/null 2>&1

echo
