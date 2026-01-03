# codex-starship: Starship prompt helper for Codex rate limits.
#
# This module is intended to be sourced by cached CLI wrappers (see `scripts/_internal/wrappers.zsh`)
# and should remain quiet at source-time.

# _codex_starship_usage [fd]
# Print CLI usage to the given file descriptor (default: stdout).
# Usage: _codex_starship_usage [fd]
_codex_starship_usage() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset fd="${1-1}"
  print -u"$fd" -r -- 'Usage: codex-starship [--no-5h] [--ttl <duration>]'
  print -u"$fd" -r --
  print -u"$fd" -r -- 'Options:'
  print -u"$fd" -r -- '  --no-5h            Hide the 5h window output'
  print -u"$fd" -r -- '  --ttl <duration>   Cache TTL (e.g. 1m, 5m); default: 5m'
  print -u"$fd" -r -- '  -h, --help         Show help'
  return 0
}

# _codex_starship_auth_file: Print the active Codex auth file path.
# Usage: _codex_starship_auth_file
_codex_starship_auth_file() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset auth_file="${CODEX_AUTH_FILE-}"
  if [[ -n "$auth_file" && -f "$auth_file" ]]; then
    print -r -- "$auth_file"
    return 0
  fi

  typeset home="${HOME-}"
  [[ -n "$home" ]] || return 1

  auth_file="$home/.config/codex-kit/auth.json"
  if [[ -f "$auth_file" ]]; then
    print -r -- "$auth_file"
    return 0
  fi

  auth_file="$home/.codex/auth.json"
  if [[ -f "$auth_file" ]]; then
    print -r -- "$auth_file"
    return 0
  fi

  return 1
}

# _codex_starship_secret_dir: Print the Codex secrets/profile directory (optional).
# Usage: _codex_starship_secret_dir
_codex_starship_secret_dir() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset secret_dir="${CODEX_SECRET_DIR-}"
  if [[ -n "$secret_dir" && -d "$secret_dir" ]]; then
    print -r -- "$secret_dir"
    return 0
  fi

  typeset zdotdir="${ZDOTDIR-}"
  if [[ -z "$zdotdir" ]]; then
    typeset home="${HOME-}"
    [[ -n "$home" ]] || return 1
    zdotdir="$home/.config/zsh"
  fi

  secret_dir="$zdotdir/.private/codex/secrets"
  if [[ -d "$secret_dir" ]]; then
    print -r -- "$secret_dir"
    return 0
  fi

  return 1
}

# _codex_starship_sha256: Print the SHA-256 digest for a file.
# Usage: _codex_starship_sha256 <file>
_codex_starship_sha256() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset file="${1-}"
  [[ -n "$file" && -f "$file" ]] || return 1

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -- "$file" 2>/dev/null | awk '{print $1}'
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$file" 2>/dev/null | awk '{print $1}'
    return 0
  fi

  return 1
}

# _codex_starship_name_from_secret_dir: Resolve a friendly name by matching auth.json hash to profiles.
# Usage: _codex_starship_name_from_secret_dir <auth_file> <secret_dir>
_codex_starship_name_from_secret_dir() {
  emulate -L zsh
  setopt pipe_fail err_return nounset nullglob

  typeset auth_file="${1-}"
  typeset secret_dir="${2-}"
  [[ -n "$auth_file" && -f "$auth_file" && -n "$secret_dir" && -d "$secret_dir" ]] || return 1

  typeset auth_hash=''
  auth_hash="$(_codex_starship_sha256 "$auth_file")" || return 1
  [[ -n "$auth_hash" ]] || return 1

  typeset secret_file=''
  for secret_file in "$secret_dir"/*.json; do
    [[ -f "$secret_file" ]] || continue

    typeset candidate_hash=''
    candidate_hash="$(_codex_starship_sha256 "$secret_file")" || continue
    if [[ "$candidate_hash" == "$auth_hash" ]]; then
      typeset name="${secret_file:t:r}"
      [[ -n "$name" ]] || return 1
      print -r -- "$name"
      return 0
    fi
  done

  return 1
}

# _codex_starship_jwt_payload: Decode and print the JWT payload JSON (base64url).
# Usage: _codex_starship_jwt_payload <jwt>
_codex_starship_jwt_payload() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset token="${1-}"
  [[ -n "$token" ]] || return 1

  typeset payload="${token#*.}"
  payload="${payload%%.*}"
  [[ -n "$payload" ]] || return 1

  payload="$(print -r -- "$payload" | tr '_-' '/+')" || return 1

  typeset -i mod=$(( ${#payload} % 4 ))
  if (( mod == 2 )); then
    payload+='=='
  elif (( mod == 3 )); then
    payload+='='
  elif (( mod == 1 )); then
    return 1
  fi

  typeset decoded=''
  if decoded="$(print -r -- "$payload" | base64 -d 2>/dev/null)"; then
    print -r -- "$decoded"
    return 0
  fi
  if decoded="$(print -r -- "$payload" | base64 -D 2>/dev/null)"; then
    print -r -- "$decoded"
    return 0
  fi

  return 1
}

# _codex_starship_auth_identity: Print a stable identity string from the auth file JWT.
# Usage: _codex_starship_auth_identity <auth_file>
_codex_starship_auth_identity() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset auth_file="${1-}"
  [[ -n "$auth_file" && -f "$auth_file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  typeset token=''
  token="$(jq -r '.tokens.id_token // empty' "$auth_file" 2>/dev/null)" || token=''
  if [[ -z "$token" ]]; then
    token="$(jq -r '.tokens.access_token // empty' "$auth_file" 2>/dev/null)" || token=''
  fi
  [[ -n "$token" ]] || return 1

  typeset payload=''
  payload="$(_codex_starship_jwt_payload "$token")" || return 1

  typeset identity=''
  identity="$(
    print -r -- "$payload" | jq -r '
      .["https://api.openai.com/auth"].chatgpt_user_id
      // .["https://api.openai.com/auth"].user_id
      // .sub
      // .email
      // empty
    ' 2>/dev/null
  )" || identity=''

  identity="${identity%%$'\n'*}"
  identity="${identity%%$'\r'*}"
  [[ -n "$identity" ]] || return 1
  print -r -- "$identity"
  return 0
}

# _codex_starship_name_from_identity: Convert a token identity into a short display name.
# Usage: _codex_starship_name_from_identity <identity>
_codex_starship_name_from_identity() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset identity="${1-}"
  [[ -n "$identity" ]] || return 1

  typeset name="$identity"
  if [[ "$name" == *'@'* ]]; then
    name="${name%%@*}"
  fi

  [[ -n "$name" ]] || return 1
  print -r -- "$name"
  return 0
}

# _codex_starship_current_name: Resolve the display name for the currently active token.
# Usage: _codex_starship_current_name <auth_file> [secret_dir]
_codex_starship_current_name() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset auth_file="${1-}"
  typeset secret_dir="${2-}"
  [[ -n "$auth_file" && -f "$auth_file" ]] || return 1

  typeset name=''
  if [[ -n "$secret_dir" && -d "$secret_dir" ]]; then
    name="$(_codex_starship_name_from_secret_dir "$auth_file" "$secret_dir")" || name=''
  fi

  if [[ -z "$name" ]]; then
    typeset identity=''
    identity="$(_codex_starship_auth_identity "$auth_file")" || return 1
    name="$(_codex_starship_name_from_identity "$identity")" || return 1
  fi

  [[ -n "$name" ]] || return 1
  print -r -- "$name"
  return 0
}

# _codex_starship_cache_key: Convert a display name into a safe cache key.
# Usage: _codex_starship_cache_key <name>
_codex_starship_cache_key() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset name="${1-}"
  [[ -n "$name" ]] || return 1

  typeset key="${name:l}"
  key="${key//[^a-z0-9]/_}"
  key="${key##_}"
  key="${key%%_}"
  [[ -n "$key" ]] || return 1

  print -r -- "$key"
  return 0
}

# _codex_starship_ttl_seconds: Convert a duration string into seconds.
# Usage: _codex_starship_ttl_seconds <duration>  # e.g. 60, 1m, 5m, 1h
_codex_starship_ttl_seconds() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset raw="${1-}"
  [[ -n "$raw" ]] || return 1

  if [[ "$raw" == <-> ]]; then
    print -r -- "$raw"
    return 0
  fi

  typeset unit="${raw[-1]}"
  typeset num="${raw[1,-2]}"
  [[ -n "$num" && "$num" == <-> ]] || return 1

  typeset -i mult=0
  case "$unit" in
    s) mult=1 ;;
    m) mult=60 ;;
    h) mult=3600 ;;
    d) mult=86400 ;;
    w) mult=604800 ;;
    *) return 1 ;;
  esac

  print -r -- $(( num * mult ))
  return 0
}

# _codex_starship_epoch_utc: Format an epoch seconds value as UTC ISO-8601.
# Usage: _codex_starship_epoch_utc <epoch_seconds>
_codex_starship_epoch_utc() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset epoch="${1-}"
  [[ -n "$epoch" && "$epoch" == <-> ]] || return 1

  typeset formatted=''
  formatted="$(date -u -r "$epoch" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)" || formatted=''
  if [[ -z "$formatted" ]]; then
    formatted="$(date -u -d "@$epoch" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)" || formatted=''
  fi

  [[ -n "$formatted" ]] || return 1
  print -r -- "$formatted"
  return 0
}

# _codex_starship_window_label: Convert limit window seconds into a short label (e.g. 5h, Weekly).
# Usage: _codex_starship_window_label <seconds>
_codex_starship_window_label() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset raw="${1-}"
  [[ -n "$raw" && "$raw" == <-> ]] || return 1

  typeset -i seconds="$raw"
  (( seconds > 0 )) || return 1

  if (( seconds % 604800 == 0 )); then
    typeset -i weeks=$(( seconds / 604800 ))
    if (( weeks == 1 )); then
      print -r -- 'Weekly'
    else
      print -r -- "${weeks}w"
    fi
    return 0
  fi
  if (( seconds % 86400 == 0 )); then
    print -r -- "$(( seconds / 86400 ))d"
    return 0
  fi
  if (( seconds % 3600 == 0 )); then
    print -r -- "$(( seconds / 3600 ))h"
    return 0
  fi
  if (( seconds % 60 == 0 )); then
    print -r -- "$(( seconds / 60 ))m"
    return 0
  fi

  print -r -- "${seconds}s"
  return 0
}

# _codex_starship_fetch_usage_json <auth_file> <out_file>
# Fetch the `wham/usage` JSON for the active token into out_file.
# Usage: _codex_starship_fetch_usage_json <auth_file> <out_file>
_codex_starship_fetch_usage_json() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset auth_file="${1-}"
  typeset out_file="${2-}"
  [[ -n "$auth_file" && -f "$auth_file" && -n "$out_file" ]] || return 1

  command -v jq >/dev/null 2>&1 || return 1
  command -v curl >/dev/null 2>&1 || return 1

  typeset access_token='' account_id=''
  access_token="$(jq -r '.tokens.access_token // empty' "$auth_file" 2>/dev/null)" || access_token=''
  account_id="$(jq -r '.tokens.account_id // empty' "$auth_file" 2>/dev/null)" || account_id=''
  [[ -n "$access_token" ]] || return 1

  typeset base_url="${CODEX_CHATGPT_BASE_URL:-https://chatgpt.com/backend-api/}"
  base_url="${base_url%/}"
  typeset url="${base_url}/wham/usage"

  typeset http_status=''
  typeset -a curl_args=(
    -s
    -o "$out_file"
    -w "%{http_code}"
    "$url"
    -H "Authorization: Bearer ${access_token}"
    -H "Accept: application/json"
    -H "User-Agent: codex-starship"
  )
  if [[ -n "$account_id" ]]; then
    curl_args+=( -H "ChatGPT-Account-Id: ${account_id}" )
  fi

  http_status="$(curl "${curl_args[@]}" 2>/dev/null)" || return 1
  [[ "$http_status" == "200" ]] || return 1

  jq -e '.' "$out_file" >/dev/null 2>&1 || return 1
  return 0
}

# codex-starship [--no-5h] [--ttl <duration>]
# Print a Starship-ready Codex rate limit line (silent failure; TTL cached).
# Usage: codex-starship [--no-5h] [--ttl <duration>]
# Output:
# - Default: <name> <window>:<pct>% W:<pct>% <weekly_reset_iso>
# - --no-5h: <name> W:<pct>% <weekly_reset_iso>
# Cache:
# - $ZSH_CACHE_DIR/codex/starship-rate-limits/<token_key>.kv
# Notes:
# - Prints nothing and exits 0 when auth/rate limits are unavailable.
codex-starship() {
  emulate -L zsh
  setopt pipe_fail nounset

  zmodload zsh/zutil 2>/dev/null || return 0

  typeset show_5h='true'
  typeset ttl='5m'

  typeset -A opts=()
  zparseopts -D -E -A opts -- \
    h -help \
    -no-5h \
    -ttl: || {
    _codex_starship_usage 2
    return 2
  }

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    _codex_starship_usage 1
    return 0
  fi

  if (( ${+opts[--no-5h]} )); then
    show_5h='false'
  fi

  if [[ -n "${opts[--ttl]-}" ]]; then
    ttl="${opts[--ttl]}"
  fi

  typeset ttl_seconds=''
  ttl_seconds="$(_codex_starship_ttl_seconds "$ttl" 2>/dev/null)" || ttl_seconds=''
  if [[ -z "$ttl_seconds" || "$ttl_seconds" != <-> ]]; then
    print -u2 -r -- "codex-starship: invalid --ttl: $ttl"
    _codex_starship_usage 2
    return 2
  fi

  typeset auth_file='' secret_dir='' name='' key=''
  auth_file="$(_codex_starship_auth_file 2>/dev/null)" || return 0
  secret_dir="$(_codex_starship_secret_dir 2>/dev/null)" || secret_dir=''
  name="$(_codex_starship_current_name "$auth_file" "$secret_dir" 2>/dev/null)" || return 0
  key="$(_codex_starship_cache_key "$name" 2>/dev/null)" || return 0

  typeset cache_root="${ZSH_CACHE_DIR-}"
  if [[ -z "$cache_root" ]]; then
    typeset zdotdir="${ZDOTDIR-}"
    if [[ -z "$zdotdir" ]]; then
      typeset home="${HOME-}"
      [[ -n "$home" ]] && zdotdir="$home/.config/zsh"
    fi
    [[ -n "$zdotdir" ]] && cache_root="$zdotdir/cache"
  fi
  [[ -n "$cache_root" ]] || return 0

  typeset cache_dir="$cache_root/codex/starship-rate-limits"
  mkdir -p -- "$cache_dir" >/dev/null 2>&1 || return 0

  typeset cache_file="$cache_dir/$key.kv"
  typeset now_epoch=''
  now_epoch="$(date +%s 2>/dev/null)" || now_epoch=''
  [[ -n "$now_epoch" && "$now_epoch" == <-> ]] || return 0

  if [[ -f "$cache_file" ]]; then
    typeset cached_fetched_at='' cached_non_weekly_label='' cached_non_weekly_remaining=''
    typeset cached_weekly_remaining='' cached_weekly_reset_iso=''

    typeset kv=''
    while IFS= read -r kv; do
      case "$kv" in
        fetched_at=*) cached_fetched_at="${kv#fetched_at=}" ;;
        non_weekly_label=*) cached_non_weekly_label="${kv#non_weekly_label=}" ;;
        non_weekly_remaining=*) cached_non_weekly_remaining="${kv#non_weekly_remaining=}" ;;
        weekly_remaining=*) cached_weekly_remaining="${kv#weekly_remaining=}" ;;
        weekly_reset_iso=*) cached_weekly_reset_iso="${kv#weekly_reset_iso=}" ;;
      esac
    done < "$cache_file" 2>/dev/null || true

    if [[ -n "$cached_fetched_at" && "$cached_fetched_at" == <-> ]]; then
      typeset -i age=$(( now_epoch - cached_fetched_at ))
      if (( age >= 0 && age < ttl_seconds )); then
        typeset out=''
        if [[ -n "$cached_weekly_remaining" && -n "$cached_weekly_reset_iso" ]]; then
          if [[ "$show_5h" == 'true' && -n "$cached_non_weekly_label" && -n "$cached_non_weekly_remaining" ]]; then
            out="${name} ${cached_non_weekly_label}:${cached_non_weekly_remaining}% W:${cached_weekly_remaining}% ${cached_weekly_reset_iso}"
          else
            out="${name} W:${cached_weekly_remaining}% ${cached_weekly_reset_iso}"
          fi
        fi
        if [[ -n "$out" ]]; then
          print -r -- "$out"
          return 0
        fi
      fi
    fi
  fi

  typeset tmp_usage=''
  tmp_usage="$(mktemp "$cache_dir/wham.usage.XXXXXX" 2>/dev/null)" || return 0
  if ! _codex_starship_fetch_usage_json "$auth_file" "$tmp_usage" >/dev/null 2>&1; then
    rm -f -- "$tmp_usage" 2>/dev/null || true
    return 0
  fi

  typeset limits_tsv=''
  limits_tsv="$(
    jq -r '
      [
        (.rate_limit.primary_window.limit_window_seconds // empty),
        (100 - (.rate_limit.primary_window.used_percent // 0) | round),
        (.rate_limit.primary_window.reset_at // empty),
        (.rate_limit.secondary_window.limit_window_seconds // empty),
        (100 - (.rate_limit.secondary_window.used_percent // 0) | round),
        (.rate_limit.secondary_window.reset_at // empty)
      ] | @tsv
    ' "$tmp_usage" 2>/dev/null
  )" || limits_tsv=''
  rm -f -- "$tmp_usage" 2>/dev/null || true
  [[ -n "$limits_tsv" ]] || return 0

  typeset primary_seconds='' primary_remaining='' primary_reset_epoch=''
  typeset secondary_seconds='' secondary_remaining='' secondary_reset_epoch=''
  IFS=$'\t' read -r primary_seconds primary_remaining primary_reset_epoch \
    secondary_seconds secondary_remaining secondary_reset_epoch <<< "$limits_tsv"

  [[ -n "$primary_seconds" && "$primary_seconds" == <-> ]] || return 0
  [[ -n "$secondary_seconds" && "$secondary_seconds" == <-> ]] || return 0
  [[ -n "$primary_remaining" && "$primary_remaining" == <-> ]] || return 0
  [[ -n "$secondary_remaining" && "$secondary_remaining" == <-> ]] || return 0

  typeset primary_label='' secondary_label=''
  primary_label="$(_codex_starship_window_label "$primary_seconds" 2>/dev/null)" || primary_label='Primary'
  secondary_label="$(_codex_starship_window_label "$secondary_seconds" 2>/dev/null)" || secondary_label='Secondary'

  typeset primary_reset_iso='' secondary_reset_iso=''
  primary_reset_iso="$(_codex_starship_epoch_utc "$primary_reset_epoch" 2>/dev/null)" || primary_reset_iso=''
  secondary_reset_iso="$(_codex_starship_epoch_utc "$secondary_reset_epoch" 2>/dev/null)" || secondary_reset_iso=''

  typeset weekly_remaining='' weekly_reset_iso=''
  typeset non_weekly_label='' non_weekly_remaining=''
  if [[ "$primary_label" == 'Weekly' ]]; then
    weekly_remaining="$primary_remaining"
    weekly_reset_iso="$primary_reset_iso"
    non_weekly_label="$secondary_label"
    non_weekly_remaining="$secondary_remaining"
  elif [[ "$secondary_label" == 'Weekly' ]]; then
    weekly_remaining="$secondary_remaining"
    weekly_reset_iso="$secondary_reset_iso"
    non_weekly_label="$primary_label"
    non_weekly_remaining="$primary_remaining"
  else
    weekly_remaining="$secondary_remaining"
    weekly_reset_iso="$secondary_reset_iso"
    non_weekly_label="$primary_label"
    non_weekly_remaining="$primary_remaining"
  fi

  [[ -n "$weekly_remaining" && -n "$weekly_reset_iso" ]] || return 0

  typeset out=''
  if [[ "$show_5h" == 'true' ]]; then
    [[ -n "$non_weekly_label" && -n "$non_weekly_remaining" ]] || return 0
    out="${name} ${non_weekly_label}:${non_weekly_remaining}% W:${weekly_remaining}% ${weekly_reset_iso}"
  else
    out="${name} W:${weekly_remaining}% ${weekly_reset_iso}"
  fi
  [[ -n "$out" ]] || return 0

  typeset tmp_cache=''
  tmp_cache="$(mktemp "${cache_file}.XXXXXX" 2>/dev/null)" || tmp_cache=''
  if [[ -n "$tmp_cache" ]]; then
    {
      print -r -- "fetched_at=$now_epoch"
      print -r -- "non_weekly_label=$non_weekly_label"
      print -r -- "non_weekly_remaining=$non_weekly_remaining"
      print -r -- "weekly_remaining=$weekly_remaining"
      print -r -- "weekly_reset_iso=$weekly_reset_iso"
    } >| "$tmp_cache" 2>/dev/null || true
    mv -f -- "$tmp_cache" "$cache_file" 2>/dev/null || rm -f -- "$tmp_cache" 2>/dev/null || true
  fi

  print -r -- "$out"
  return 0
}
