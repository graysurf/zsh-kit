# Prevent double execution
[[ -n "$_LOGIN_SH_EXECUTED" ]] && return
export _LOGIN_SH_EXECUTED=1

# Quote storage path
QUOTES_FILE="$ZDOTDIR/assets/quotes.txt"
QUOTES_TIMESTAMP_FILE="$ZSH_CACHE_DIR/quotes.timestamp"
QUOTE_FETCH_INTERVAL=3600  # seconds (1 hour)

now=$(date +%s)
last_fetch=0
[[ -f "$QUOTES_TIMESTAMP_FILE" ]] && last_fetch=$(cat "$QUOTES_TIMESTAMP_FILE" 2>/dev/null)

# Show local quote first
if [[ -f "$QUOTES_FILE" && -s "$QUOTES_FILE" ]]; then
  quote_line=$(shuf -n 1 "$QUOTES_FILE")
  printf "\n📜 %s\n" "$quote_line"
else
  printf "\n💬 \"Stay hungry, stay foolish.\" — Steve Jobs\n"
fi

# Decide whether to fetch a new quote
if (( now - last_fetch > QUOTE_FETCH_INTERVAL )); then
  (
    nohup bash -c '
      quote_json=$(curl -s --max-time 2 "https://zenquotes.io/api/random")
      quote=$(printf "%s" "$quote_json" | jq -r ".[0].q" 2>/dev/null)
      author=$(printf "%s" "$quote_json" | jq -r ".[0].a" 2>/dev/null)

      if [[ -n "$quote" && "$quote" != "null" && -n "$author" && "$author" != "null" ]]; then
        printf "\"%s\" — %s\n" "$quote" "$author" >> "'"$QUOTES_FILE"'"
        tail -n 100 "'"$QUOTES_FILE"'" > "'"$QUOTES_FILE"'.tmp" && \
          mv "'"$QUOTES_FILE"'.tmp" "'"$QUOTES_FILE"'"
        date +%s > "'"$QUOTES_TIMESTAMP_FILE"'"
      fi
    ' &> /dev/null &
  ) >/dev/null 2>&1
fi

printf "\n"

# Load emoji function
emoji() {
  "$ZDOTDIR/tools/random_emoji_cmd.sh"
}

printf "$(emoji)  Thinking shell initialized. Expect consequences...\n\n"
