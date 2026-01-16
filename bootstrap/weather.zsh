# Prevent double execution
[[ -n "$_LOGIN_WEATHER_EXECUTED" ]] && return
export _LOGIN_WEATHER_EXECUTED=true

typeset -r WEATHER_URL="${ZSH_WEATHER_URL:-https://wttr.in/?0}"
typeset -i WEATHER_FETCH_INTERVAL=${ZSH_WEATHER_INTERVAL:-3600}
typeset -r WEATHER_CACHE_FILE="${ZSH_CACHE_DIR}/weather.txt"
typeset -r WEATHER_TIMESTAMP_FILE="${ZSH_CACHE_DIR}/weather.timestamp"

[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p "$ZSH_CACHE_DIR"

typeset -i now=${EPOCHSECONDS:-0}
if (( now == 0 )); then
  now=$(date +%s)
fi
typeset -i last_fetch=0

if [[ -r "$WEATHER_TIMESTAMP_FILE" ]]; then
  typeset timestamp_content=''
  IFS=$'\n' read -r timestamp_content < "$WEATHER_TIMESTAMP_FILE"
  [[ -n "$timestamp_content" ]] && last_fetch=$timestamp_content
fi

typeset -i fetch_needed=0
if [[ ! -s "$WEATHER_CACHE_FILE" ]]; then
  fetch_needed=1
elif (( now - last_fetch >= WEATHER_FETCH_INTERVAL )); then
  fetch_needed=1
fi

if (( fetch_needed )); then
  typeset weather_output=''
  if weather_output=$(curl -fsS --max-time 4 "$WEATHER_URL"); then
    typeset tmp_file="${WEATHER_CACHE_FILE}.tmp.$$"
    printf "%s\n" "$weather_output" >| "$tmp_file"
    mv -f "$tmp_file" "$WEATHER_CACHE_FILE"
    printf "%s\n" "$now" >| "$WEATHER_TIMESTAMP_FILE"
  else
    printf "%s\n" "$now" >| "$WEATHER_TIMESTAMP_FILE"
  fi
fi

printf "\n"

if [[ -s "$WEATHER_CACHE_FILE" ]]; then
  cat -- "$WEATHER_CACHE_FILE"
else
  print -r -- "Weather report unavailable."
fi
