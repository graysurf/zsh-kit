# codex-starship: Starship prompt helper for Codex rate limits.
#
# This module is intended to be sourced by cached CLI wrappers (see `scripts/_internal/wrappers.zsh`)
# and should remain quiet at source-time.

# ────────────────────────────────────────────────────────
# CLI helpers
# ────────────────────────────────────────────────────────

# _codex_starship_usage [fd]
# Print CLI usage to the given file descriptor (default: stdout).
# Usage: _codex_starship_usage [fd]
_codex_starship_usage() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset fd="${1-1}"
  print -u"$fd" -r -- 'Usage: codex-starship [--no-5h] [--ttl <duration>] [--time-format <strftime>] [--refresh]'
  print -u"$fd" -r --
  print -u"$fd" -r -- 'Options:'
  print -u"$fd" -r -- '  --no-5h            Hide the 5h window output'
  print -u"$fd" -r -- '  --ttl <duration>   Cache TTL (e.g. 1m, 5m); default: 5m'
  print -u"$fd" -r -- '  --time-format <f>  Reset time format (UTC; default: %m-%d %H:%M)'
  print -u"$fd" -r -- '  --refresh          Force a blocking refresh (updates cache)'
  print -u"$fd" -r -- '  -h, --help         Show help'
  return 0
}

# _codex_starship_truthy: Return 0 if the input string is truthy (1/true/yes/on).
# Usage: _codex_starship_truthy <value>
_codex_starship_truthy() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset raw="${1-}"
  raw="${raw:l}"
  case "$raw" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

# ────────────────────────────────────────────────────────
# Auth & identity
# ────────────────────────────────────────────────────────

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

# _codex_starship_auth_account_id: Print the ChatGPT account_id from the auth file (if available).
# Usage: _codex_starship_auth_account_id <auth_file>
_codex_starship_auth_account_id() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset auth_file="${1-}"
  [[ -n "$auth_file" && -f "$auth_file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  typeset account_id=''
  account_id="$(jq -r '.tokens.account_id // .account_id // empty' "$auth_file" 2>/dev/null)" || account_id=''
  account_id="${account_id%%$'\n'*}"
  account_id="${account_id%%$'\r'*}"
  [[ -n "$account_id" ]] || return 1

  print -r -- "$account_id"
  return 0
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

# _codex_starship_auth_identity_key: Build a stable match key from the auth file identity + account_id (if any).
# Usage: _codex_starship_auth_identity_key <auth_file>
_codex_starship_auth_identity_key() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset auth_file="${1-}"
  [[ -n "$auth_file" && -f "$auth_file" ]] || return 1

  typeset identity=''
  identity="$(_codex_starship_auth_identity "$auth_file")" || return 1

  typeset account_id=''
  account_id="$(_codex_starship_auth_account_id "$auth_file")" || account_id=''

  typeset key="$identity"
  if [[ -n "$account_id" ]]; then
    key="${identity}::${account_id}"
  fi

  [[ -n "$key" ]] || return 1
  print -r -- "$key"
  return 0
}

# _codex_starship_name_from_secret_dir: Resolve a friendly name by matching auth.json hash to profiles.
# Usage: _codex_starship_name_from_secret_dir <auth_file> <secret_dir>
_codex_starship_name_from_secret_dir() {
  emulate -L zsh
  setopt pipe_fail err_return nounset nullglob

  typeset auth_file="${1-}"
  typeset secret_dir="${2-}"
  [[ -n "$auth_file" && -f "$auth_file" && -n "$secret_dir" && -d "$secret_dir" ]] || return 1

  typeset auth_key=''
  auth_key="$(_codex_starship_auth_identity_key "$auth_file")" || auth_key=''
  if [[ -n "$auth_key" ]]; then
    typeset secret_file='' candidate_key=''
    for secret_file in "$secret_dir"/*.json; do
      [[ -f "$secret_file" ]] || continue

      candidate_key="$(_codex_starship_auth_identity_key "$secret_file")" || continue
      if [[ "$candidate_key" == "$auth_key" ]]; then
        typeset name="${secret_file:t:r}"
        [[ -n "$name" ]] || return 1
        print -r -- "$name"
        return 0
      fi
    done
  fi

  typeset auth_hash=''
  auth_hash="$(_codex_starship_sha256 "$auth_file")" || return 1
  [[ -n "$auth_hash" ]] || return 1

  typeset secret_file='' candidate_hash=''
  for secret_file in "$secret_dir"/*.json; do
    [[ -f "$secret_file" ]] || continue

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

# ────────────────────────────────────────────────────────
# Cache & TTL
# ────────────────────────────────────────────────────────

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

# ────────────────────────────────────────────────────────
# Time formatting
# ────────────────────────────────────────────────────────

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

# _codex_starship_epoch_utc_format: Format an epoch seconds value in UTC using a strftime format.
# Usage: _codex_starship_epoch_utc_format <epoch_seconds> <format>
_codex_starship_epoch_utc_format() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset epoch="${1-}"
  typeset format="${2-}"
  [[ -n "$epoch" && "$epoch" == <-> && -n "$format" ]] || return 1

  if [[ "$format" != +* ]]; then
    format="+$format"
  fi

  typeset formatted=''
  formatted="$(date -u -r "$epoch" "$format" 2>/dev/null)" || formatted=''
  if [[ -z "$formatted" ]]; then
    formatted="$(date -u -d "@$epoch" "$format" 2>/dev/null)" || formatted=''
  fi

  [[ -n "$formatted" ]] || return 1
  print -r -- "$formatted"
  return 0
}

# _codex_starship_normalize_iso: Normalize an ISO-8601 timestamp string (trim newlines, strip fractional seconds).
# Usage: _codex_starship_normalize_iso <iso>
_codex_starship_normalize_iso() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset iso="${1-}"
  [[ -n "$iso" ]] || return 1

  iso="${iso%%$'\n'*}"
  iso="${iso%%$'\r'*}"
  if [[ "$iso" == *.*Z ]]; then
    iso="${iso%%.*}Z"
  fi

  [[ -n "$iso" ]] || return 1
  print -r -- "$iso"
  return 0
}

# _codex_starship_iso_to_epoch_utc: Convert an ISO-8601 UTC timestamp (YYYY-MM-DDTHH:MM:SSZ) to epoch seconds.
# Usage: _codex_starship_iso_to_epoch_utc <iso>
_codex_starship_iso_to_epoch_utc() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset iso_raw="${1-}"
  [[ -n "$iso_raw" ]] || return 1

  typeset iso=''
  iso="$(_codex_starship_normalize_iso "$iso_raw")" || return 1

  typeset epoch=''
  if epoch="$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso" "+%s" 2>/dev/null)"; then
    [[ -n "$epoch" && "$epoch" == <-> ]] || return 1
    print -r -- "$epoch"
    return 0
  fi

  if epoch="$(date -u -d "$iso" "+%s" 2>/dev/null)"; then
    [[ -n "$epoch" && "$epoch" == <-> ]] || return 1
    print -r -- "$epoch"
    return 0
  fi

  return 1
}

# ────────────────────────────────────────────────────────
# Refresh & locking
# ────────────────────────────────────────────────────────

# _codex_starship_spawn_refresh: Spawn a detached refresh process to update the cache.
# Usage: _codex_starship_spawn_refresh
_codex_starship_spawn_refresh() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  command -v nohup >/dev/null 2>&1 || return 1

  typeset wrapper=''
  wrapper="$(whence -p codex-starship 2>/dev/null)" || wrapper=''
  if [[ -n "$wrapper" && -x "$wrapper" ]]; then
    nohup "$wrapper" --refresh >/dev/null 2>&1 &
    return 0
  fi

  typeset script_dir="${ZSH_SCRIPT_DIR-}"
  [[ -n "$script_dir" ]] || return 1

  typeset script=''
  for script in \
    "$script_dir/_features/codex/codex-starship.zsh" \
    "$script_dir/codex-starship.zsh"
  do
    [[ -f "$script" ]] && break
    script=''
  done
  [[ -n "$script" ]] || return 1

  typeset cache_root="${ZSH_CACHE_DIR-}"
  [[ -n "$cache_root" ]] || return 1

  nohup zsh -f -c \
    "export ZSH_SCRIPT_DIR=${(q)script_dir}; export ZSH_CACHE_DIR=${(q)cache_root}; source ${(q)script}; codex-starship --refresh" \
    >/dev/null 2>&1 &
  return 0
}

# _codex_starship_clear_stale_refresh_lock: Remove a stale refresh lock directory/file.
# Usage: _codex_starship_clear_stale_refresh_lock <lock_path> <now_epoch> [stale_after_seconds]
_codex_starship_clear_stale_refresh_lock() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset lock_path="${1-}"
  typeset now_epoch="${2-}"
  typeset stale_after="${3-}"

  [[ -n "$lock_path" && -e "$lock_path" && -n "$now_epoch" && "$now_epoch" == <-> ]] || return 1
  [[ -n "$stale_after" && "$stale_after" == <-> ]] || stale_after='90'

  zmodload zsh/stat 2>/dev/null || return 1

  typeset -a st=()
  zstat -A st +mtime -- "$lock_path" 2>/dev/null || return 1

  typeset mtime="${st[1]-}"
  [[ -n "$mtime" && "$mtime" == <-> ]] || return 1

  typeset -i age=$(( now_epoch - mtime ))
  if (( age < stale_after )); then
    return 1
  fi

  if [[ -d "$lock_path" ]]; then
    if rmdir -- "$lock_path" 2>/dev/null; then
      return 0
    fi
    if [[ "${lock_path:t}" == *.refresh.lock ]]; then
      rm -rf -- "$lock_path" 2>/dev/null || return 1
    else
      return 1
    fi
  else
    rm -f -- "$lock_path" 2>/dev/null || return 1
  fi

  return 0
}

# _codex_starship_cleanup_stale_wham_usage_files: Remove stale wham.usage.* temp files in the cache dir.
# Usage: _codex_starship_cleanup_stale_wham_usage_files <cache_dir> <now_epoch> [stale_after_seconds]
_codex_starship_cleanup_stale_wham_usage_files() {
  emulate -L zsh
  setopt pipe_fail err_return nounset nullglob

  typeset cache_dir="${1-}"
  typeset now_epoch="${2-}"
  typeset stale_after="${3-}"

  [[ -n "$cache_dir" && -d "$cache_dir" && -n "$now_epoch" && "$now_epoch" == <-> ]] || return 1
  [[ -n "$stale_after" && "$stale_after" == <-> ]] || stale_after='90'

  typeset -a candidates=("$cache_dir"/wham.usage.*(N))
  (( ${#candidates} )) || return 1

  zmodload zsh/stat 2>/dev/null || return 1

  typeset candidate=''
  for candidate in "${candidates[@]}"; do
    [[ -f "$candidate" ]] || continue

    typeset -a st=()
    zstat -A st +mtime -- "$candidate" 2>/dev/null || continue
    typeset mtime="${st[1]-}"
    [[ -n "$mtime" && "$mtime" == <-> ]] || continue

    typeset -i age=$(( now_epoch - mtime ))
    if (( age >= stale_after )); then
      rm -f -- "$candidate" 2>/dev/null || true
    fi
  done

  return 0
}

# _codex_starship_cleanup_stale_refresh_locks: Remove stale *.refresh.lock dirs/files in the cache dir.
# Usage: _codex_starship_cleanup_stale_refresh_locks <cache_dir> <now_epoch> [stale_after_seconds]
_codex_starship_cleanup_stale_refresh_locks() {
  emulate -L zsh
  setopt pipe_fail err_return nounset nullglob

  typeset cache_dir="${1-}"
  typeset now_epoch="${2-}"
  typeset stale_after="${3-}"

  [[ -n "$cache_dir" && -d "$cache_dir" && -n "$now_epoch" && "$now_epoch" == <-> ]] || return 1
  [[ -n "$stale_after" && "$stale_after" == <-> ]] || stale_after='90'

  typeset -a candidates=("$cache_dir"/*.refresh.lock(N))
  (( ${#candidates} )) || return 1

  typeset candidate=''
  for candidate in "${candidates[@]}"; do
    [[ -e "$candidate" ]] || continue
    _codex_starship_clear_stale_refresh_lock "$candidate" "$now_epoch" "$stale_after" >/dev/null 2>&1 || true
  done

  return 0
}

# _codex_starship_cleanup_auth_hash_cache: Limit auth_<sha256> cache artifacts to avoid unbounded growth.
# Usage: _codex_starship_cleanup_auth_hash_cache <cache_dir> <active_key> <now_epoch> [keep]
_codex_starship_cleanup_auth_hash_cache() {
  emulate -L zsh
  setopt pipe_fail err_return nounset nullglob

  typeset cache_dir="${1-}"
  typeset active_key="${2-}"
  typeset now_epoch="${3-}"
  typeset keep="${4-}"

  [[ -n "$cache_dir" && -d "$cache_dir" && -n "$now_epoch" && "$now_epoch" == <-> ]] || return 1
  [[ -n "$keep" && "$keep" == <-> ]] || keep='5'

  typeset -i keep_n="$keep"
  if (( keep_n < 1 )); then
    return 0
  fi

  typeset -a candidates=("$cache_dir"/auth_*.kv(N) "$cache_dir"/auth_*.refresh.at(N))
  (( ${#candidates} )) || return 1

  zmodload zsh/stat 2>/dev/null || return 1

  typeset -A key_mtime=()
  typeset candidate=''
  for candidate in "${candidates[@]}"; do
    [[ -f "$candidate" ]] || continue

    typeset base="${candidate:t}"
    case "$base" in
      auth_*.kv) base="${base%.kv}" ;;
      auth_*.refresh.at) base="${base%.refresh.at}" ;;
      *) continue ;;
    esac
    [[ -n "$base" ]] || continue

    typeset -a st=()
    zstat -A st +mtime -- "$candidate" 2>/dev/null || continue
    typeset mtime="${st[1]-}"
    [[ -n "$mtime" && "$mtime" == <-> ]] || continue

    typeset prev="${key_mtime[$base]-}"
    if [[ -z "$prev" || "$prev" != <-> ]]; then
      key_mtime[$base]="$mtime"
      continue
    fi

    typeset -i prev_i="$prev" mtime_i="$mtime"
    if (( mtime_i > prev_i )); then
      key_mtime[$base]="$mtime"
    fi
  done

  typeset -a keys=(${(k)key_mtime})
  (( ${#keys} > keep_n )) || return 0

  typeset -a entries=()
  typeset k=''
  for k in "${keys[@]}"; do
    typeset m="${key_mtime[$k]-}"
    [[ -n "$m" && "$m" == <-> ]] || continue
    entries+=("${m} ${k}")
  done
  (( ${#entries} )) || return 0
  entries=("${(@On)entries}")

  typeset -A keep_set=()
  typeset -i kept=0

  if [[ -n "$active_key" && "$active_key" == auth_* && -n "${key_mtime[$active_key]-}" ]]; then
    keep_set[$active_key]=1
    kept=1
  fi

  typeset entry=''
  for entry in "${entries[@]}"; do
    (( kept >= keep_n )) && break

    k="${entry#* }"
    [[ -n "$k" ]] || continue

    [[ -n "${keep_set[$k]-}" ]] && continue
    keep_set[$k]=1
    (( kept++ ))
  done

  for candidate in "${candidates[@]}"; do
    [[ -f "$candidate" ]] || continue

    typeset base="${candidate:t}"
    case "$base" in
      auth_*.kv) base="${base%.kv}" ;;
      auth_*.refresh.at) base="${base%.refresh.at}" ;;
      *) continue ;;
    esac
    [[ -n "$base" ]] || continue

    [[ -n "${keep_set[$base]-}" ]] && continue
    rm -f -- "$candidate" 2>/dev/null || true
  done

  return 0
}

# _codex_starship_maybe_enqueue_refresh: Enqueue a background refresh if not already refreshing and not too soon.
# Usage: _codex_starship_maybe_enqueue_refresh <cache_dir> <key> <now_epoch> <min_interval_seconds>
_codex_starship_maybe_enqueue_refresh() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset cache_dir="${1-}"
  typeset key="${2-}"
  typeset now_epoch="${3-}"
  typeset min_interval="${4-}"

  [[ -n "$cache_dir" && -d "$cache_dir" && -n "$key" && -n "$now_epoch" && "$now_epoch" == <-> ]] || return 1
  [[ -n "$min_interval" && "$min_interval" == <-> ]] || min_interval='30'

  typeset lock_dir="$cache_dir/$key.refresh.lock"
  typeset stale_after="${CODEX_STARSHIP_LOCK_STALE_SECONDS:-90}"

  if [[ -e "$lock_dir" ]]; then
    _codex_starship_clear_stale_refresh_lock "$lock_dir" "$now_epoch" "$stale_after" >/dev/null 2>&1 || return 0
  fi

  typeset attempt_file="$cache_dir/$key.refresh.at"
  if [[ -f "$attempt_file" ]]; then
    typeset last_attempt=''
    last_attempt="$(<"$attempt_file" 2>/dev/null)" || last_attempt=''
    last_attempt="${last_attempt%%$'\n'*}"
    last_attempt="${last_attempt%%$'\r'*}"
    if [[ -n "$last_attempt" && "$last_attempt" == <-> ]]; then
      typeset -i age=$(( now_epoch - last_attempt ))
      if (( age >= 0 && age < min_interval )); then
        return 0
      fi
    fi
  fi

  typeset tmp_attempt=''
  tmp_attempt="$(mktemp "${attempt_file}.XXXXXX" 2>/dev/null)" || tmp_attempt=''
  if [[ -n "$tmp_attempt" ]]; then
    print -r -- "$now_epoch" >| "$tmp_attempt" 2>/dev/null || true
    mv -f -- "$tmp_attempt" "$attempt_file" 2>/dev/null || rm -f -- "$tmp_attempt" 2>/dev/null || true
  fi

  _codex_starship_spawn_refresh >/dev/null 2>&1 || true
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

# ────────────────────────────────────────────────────────
# Network fetch
# ────────────────────────────────────────────────────────

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
  typeset connect_timeout="${CODEX_STARSHIP_CURL_CONNECT_TIMEOUT_SECONDS:-2}"
  typeset max_time="${CODEX_STARSHIP_CURL_MAX_TIME_SECONDS:-8}"
  [[ -n "$connect_timeout" && "$connect_timeout" == <-> ]] || connect_timeout='2'
  [[ -n "$max_time" && "$max_time" == <-> ]] || max_time='8'
  typeset -a curl_args=(
    -s
    -o "$out_file"
    -w "%{http_code}"
    --connect-timeout "$connect_timeout"
    --max-time "$max_time"
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

# ────────────────────────────────────────────────────────
# Entrypoint
# ────────────────────────────────────────────────────────

# codex-starship [--no-5h] [--ttl <duration>] [--time-format <strftime>] [--refresh]
# Print a Starship-ready Codex rate limit line (silent failure; stale-while-revalidate cached).
# Usage: codex-starship [--no-5h] [--ttl <duration>] [--time-format <strftime>] [--refresh]
# Output:
# - Default: <name> <window>:<pct>% W:<pct>% <weekly_reset_time>
# - --no-5h: <name> W:<pct>% <weekly_reset_time>
# Cache:
# - $ZSH_CACHE_DIR/codex/starship-rate-limits/<token_key>.kv
# Notes:
# - Prints nothing and exits 0 when auth/rate limits are unavailable.
# - In normal mode, prints cached output immediately (even if stale) and refreshes in the background.
codex-starship() {
  emulate -L zsh
  setopt pipe_fail nounset

  zmodload zsh/zutil 2>/dev/null || return 0

  typeset show_5h='true'
  if [[ -n "${CODEX_STARSHIP_SHOW_5H-}" ]]; then
    if _codex_starship_truthy "${CODEX_STARSHIP_SHOW_5H}"; then
      show_5h='true'
    else
      show_5h='false'
    fi
  fi

  typeset ttl="${CODEX_STARSHIP_TTL-}"
  [[ -n "$ttl" ]] || ttl='5m'
  typeset time_format='%m-%d %H:%M'
  typeset refresh='false'

  typeset -A opts=()
  zparseopts -D -E -A opts -- \
    h -help \
    -no-5h \
    -ttl: \
    -time-format: \
    -refresh || {
    _codex_starship_usage 2
    return 2
  }

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    _codex_starship_usage 1
    return 0
  fi

  if ! _codex_starship_truthy "${CODEX_STARSHIP_ENABLED-}"; then
    return 0
  fi

  if (( ${+opts[--no-5h]} )); then
    show_5h='false'
  fi

  if [[ -n "${opts[--ttl]-}" ]]; then
    ttl="${opts[--ttl]}"
  fi

  if [[ -n "${opts[--time-format]-}" ]]; then
    time_format="${opts[--time-format]}"
  fi
  [[ -n "$time_format" ]] || time_format='%m-%d %H:%M'

  if (( ${+opts[--refresh]} )); then
    refresh='true'
  fi

  typeset ttl_seconds=''
  ttl_seconds="$(_codex_starship_ttl_seconds "$ttl" 2>/dev/null)" || ttl_seconds=''
  if [[ -z "$ttl_seconds" || "$ttl_seconds" != <-> ]]; then
    if [[ -n "${opts[--ttl]-}" ]]; then
      print -u2 -r -- "codex-starship: invalid --ttl: $ttl"
      _codex_starship_usage 2
      return 2
    fi

    ttl='5m'
    ttl_seconds="$(_codex_starship_ttl_seconds "$ttl" 2>/dev/null)" || ttl_seconds='300'
  fi

  typeset auth_file='' secret_dir='' name='' key='' secret_name=''
  auth_file="$(_codex_starship_auth_file 2>/dev/null)" || return 0
  secret_dir="$(_codex_starship_secret_dir 2>/dev/null)" || secret_dir=''

  if [[ -n "$secret_dir" && -d "$secret_dir" ]]; then
    secret_name="$(_codex_starship_name_from_secret_dir "$auth_file" "$secret_dir" 2>/dev/null)" || secret_name=''
  fi

  if [[ -n "$secret_name" ]]; then
    name="$secret_name"
    key="$(_codex_starship_cache_key "$name" 2>/dev/null)" || return 0
  else
    typeset auth_hash=''
    auth_hash="$(_codex_starship_sha256 "$auth_file" 2>/dev/null)" || auth_hash=''
    auth_hash="${auth_hash:l}"
    [[ -n "$auth_hash" ]] || return 0
    key="auth_${auth_hash}"

    if _codex_starship_truthy "${CODEX_STARSHIP_SHOW_FALLBACK_NAME-}"; then
      typeset identity=''
      identity="$(_codex_starship_auth_identity "$auth_file" 2>/dev/null)" || identity=''
      if [[ -n "$identity" ]]; then
        name="$(_codex_starship_name_from_identity "$identity" 2>/dev/null)" || name=''
      fi
    fi
  fi

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

  typeset refresh_stale_after="${CODEX_STARSHIP_LOCK_STALE_SECONDS:-90}"
  _codex_starship_cleanup_stale_refresh_locks "$cache_dir" "$now_epoch" "$refresh_stale_after" >/dev/null 2>&1 || true
  _codex_starship_cleanup_stale_wham_usage_files "$cache_dir" "$now_epoch" "$refresh_stale_after" >/dev/null 2>&1 || true
  typeset auth_hash_keep="${CODEX_STARSHIP_AUTH_HASH_CACHE_KEEP:-5}"
  _codex_starship_cleanup_auth_hash_cache "$cache_dir" "$key" "$now_epoch" "$auth_hash_keep" >/dev/null 2>&1 || true

  typeset name_prefix=''
  if [[ -n "$name" ]]; then
    name_prefix="${name} "
  fi

  typeset cached_out='' cached_is_fresh='false'
  if [[ -f "$cache_file" ]]; then
    typeset cached_fetched_at='' cached_non_weekly_label='' cached_non_weekly_remaining=''
    typeset cached_weekly_remaining='' cached_weekly_reset_epoch='' cached_weekly_reset_iso=''

    typeset kv=''
    while IFS= read -r kv; do
      case "$kv" in
        fetched_at=*) cached_fetched_at="${kv#fetched_at=}" ;;
        non_weekly_label=*) cached_non_weekly_label="${kv#non_weekly_label=}" ;;
        non_weekly_remaining=*) cached_non_weekly_remaining="${kv#non_weekly_remaining=}" ;;
        weekly_remaining=*) cached_weekly_remaining="${kv#weekly_remaining=}" ;;
        weekly_reset_epoch=*) cached_weekly_reset_epoch="${kv#weekly_reset_epoch=}" ;;
        weekly_reset_iso=*) cached_weekly_reset_iso="${kv#weekly_reset_iso=}" ;;
      esac
    done < "$cache_file" 2>/dev/null || true

    if [[ -n "$cached_fetched_at" && "$cached_fetched_at" == <-> ]]; then
      typeset -i age=$(( now_epoch - cached_fetched_at ))
      if (( age >= 0 && age < ttl_seconds )); then
        cached_is_fresh='true'
      fi
    fi

    if [[ -z "$cached_weekly_reset_epoch" && -n "$cached_weekly_reset_iso" ]]; then
      cached_weekly_reset_epoch="$(_codex_starship_iso_to_epoch_utc "$cached_weekly_reset_iso" 2>/dev/null)" || cached_weekly_reset_epoch=''
    fi

    typeset cached_weekly_reset=''
    if [[ -n "$cached_weekly_reset_epoch" && "$cached_weekly_reset_epoch" == <-> ]]; then
      cached_weekly_reset="$(_codex_starship_epoch_utc_format "$cached_weekly_reset_epoch" "$time_format" 2>/dev/null)" || cached_weekly_reset=''
    fi

    if [[ -n "$cached_weekly_remaining" && -n "$cached_weekly_reset" ]]; then
      if [[ "$show_5h" == 'true' && -n "$cached_non_weekly_label" && -n "$cached_non_weekly_remaining" ]]; then
        cached_out="${name_prefix}${cached_non_weekly_label}:${cached_non_weekly_remaining}% W:${cached_weekly_remaining}% ${cached_weekly_reset}"
      else
        cached_out="${name_prefix}W:${cached_weekly_remaining}% ${cached_weekly_reset}"
      fi
    fi
  fi

  if [[ "$refresh" != 'true' ]]; then
    if [[ -n "$cached_out" ]]; then
      typeset out="$cached_out"
      if [[ "$cached_is_fresh" != 'true' ]]; then
        typeset stale_suffix="${CODEX_STARSHIP_STALE_SUFFIX- (stale)}"
        stale_suffix="${stale_suffix%%$'\n'*}"
        stale_suffix="${stale_suffix%%$'\r'*}"
        if [[ -n "$stale_suffix" ]]; then
          out+="$stale_suffix"
        fi
      fi
      print -r -- "$out"
    fi

    if [[ -z "$cached_out" || "$cached_is_fresh" != 'true' ]]; then
      typeset refresh_min_interval="${CODEX_STARSHIP_REFRESH_MIN_SECONDS:-30}"
      _codex_starship_maybe_enqueue_refresh "$cache_dir" "$key" "$now_epoch" "$refresh_min_interval" >/dev/null 2>&1 || true
    fi
    return 0
  fi

  (
    emulate -L zsh
    setopt pipe_fail nounset

    typeset lock_dir="$cache_dir/$key.refresh.lock"
    typeset stale_after="${CODEX_STARSHIP_LOCK_STALE_SECONDS:-90}"
    if ! mkdir "$lock_dir" >/dev/null 2>&1; then
      _codex_starship_clear_stale_refresh_lock "$lock_dir" "$now_epoch" "$stale_after" >/dev/null 2>&1 || true
      mkdir "$lock_dir" >/dev/null 2>&1 || exit 0
    fi

    typeset tmp_usage=''
    trap 'rm -f -- "$tmp_usage" 2>/dev/null || true; rmdir -- "$lock_dir" 2>/dev/null || true' EXIT

    tmp_usage="$(mktemp "$cache_dir/wham.usage.XXXXXX" 2>/dev/null)" || exit 0

    if ! _codex_starship_fetch_usage_json "$auth_file" "$tmp_usage" >/dev/null 2>&1; then
      exit 0
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
    [[ -n "$limits_tsv" ]] || exit 0

    typeset primary_seconds='' primary_remaining='' primary_reset_epoch=''
    typeset secondary_seconds='' secondary_remaining='' secondary_reset_epoch=''
    IFS=$'\t' read -r primary_seconds primary_remaining primary_reset_epoch \
      secondary_seconds secondary_remaining secondary_reset_epoch <<< "$limits_tsv"

    [[ -n "$primary_seconds" && "$primary_seconds" == <-> ]] || exit 0
    [[ -n "$secondary_seconds" && "$secondary_seconds" == <-> ]] || exit 0
    [[ -n "$primary_remaining" && "$primary_remaining" == <-> ]] || exit 0
    [[ -n "$secondary_remaining" && "$secondary_remaining" == <-> ]] || exit 0

    typeset primary_label='' secondary_label=''
    primary_label="$(_codex_starship_window_label "$primary_seconds" 2>/dev/null)" || primary_label='Primary'
    secondary_label="$(_codex_starship_window_label "$secondary_seconds" 2>/dev/null)" || secondary_label='Secondary'

    typeset weekly_remaining='' weekly_reset_epoch=''
    typeset non_weekly_label='' non_weekly_remaining=''
    if [[ "$primary_label" == 'Weekly' ]]; then
      weekly_remaining="$primary_remaining"
      weekly_reset_epoch="$primary_reset_epoch"
      non_weekly_label="$secondary_label"
      non_weekly_remaining="$secondary_remaining"
    elif [[ "$secondary_label" == 'Weekly' ]]; then
      weekly_remaining="$secondary_remaining"
      weekly_reset_epoch="$secondary_reset_epoch"
      non_weekly_label="$primary_label"
      non_weekly_remaining="$primary_remaining"
    else
      weekly_remaining="$secondary_remaining"
      weekly_reset_epoch="$secondary_reset_epoch"
      non_weekly_label="$primary_label"
      non_weekly_remaining="$primary_remaining"
    fi

    [[ -n "$weekly_remaining" && -n "$weekly_reset_epoch" && "$weekly_reset_epoch" == <-> ]] || exit 0

    typeset weekly_reset=''
    weekly_reset="$(_codex_starship_epoch_utc_format "$weekly_reset_epoch" "$time_format" 2>/dev/null)" || weekly_reset=''
    [[ -n "$weekly_reset" ]] || exit 0

    typeset out=''
    if [[ "$show_5h" == 'true' ]]; then
      [[ -n "$non_weekly_label" && -n "$non_weekly_remaining" ]] || exit 0
      out="${name_prefix}${non_weekly_label}:${non_weekly_remaining}% W:${weekly_remaining}% ${weekly_reset}"
    else
      out="${name_prefix}W:${weekly_remaining}% ${weekly_reset}"
    fi
    [[ -n "$out" ]] || exit 0

    typeset tmp_cache=''
    tmp_cache="$(mktemp "${cache_file}.XXXXXX" 2>/dev/null)" || tmp_cache=''
    if [[ -n "$tmp_cache" ]]; then
      {
        print -r -- "fetched_at=$now_epoch"
        print -r -- "non_weekly_label=$non_weekly_label"
        print -r -- "non_weekly_remaining=$non_weekly_remaining"
        print -r -- "weekly_remaining=$weekly_remaining"
        print -r -- "weekly_reset_epoch=$weekly_reset_epoch"
      } >| "$tmp_cache" 2>/dev/null || true
      mv -f -- "$tmp_cache" "$cache_file" 2>/dev/null || rm -f -- "$tmp_cache" 2>/dev/null || true
    fi

    print -r -- "$out"
    exit 0
  ) || true

  return 0
}
