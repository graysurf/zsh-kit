#!/usr/bin/env -S zsh -f

if command -v safe_unalias >/dev/null; then
  safe_unalias \
    crl
fi

typeset -gr CODEX_SCRIPT_PATH="${(%):-%N}"
typeset -gr CODEX_SECRET_DIR="${CODEX_SCRIPT_PATH:A:h}"
typeset -gr _CODEX_AUTH_FILE_PRIMARY="${HOME}/.config/codex-kit/auth.json"
typeset -gr _CODEX_AUTH_FILE_FALLBACK="${HOME}/.codex/auth.json"
typeset -g CODEX_AUTH_FILE="${CODEX_AUTH_FILE:-${_CODEX_AUTH_FILE_PRIMARY}}"
if [[ "${CODEX_AUTH_FILE}" == "${_CODEX_AUTH_FILE_PRIMARY}" && ! -f "${_CODEX_AUTH_FILE_PRIMARY}" && -f "${_CODEX_AUTH_FILE_FALLBACK}" ]]; then
  CODEX_AUTH_FILE="${_CODEX_AUTH_FILE_FALLBACK}"
elif [[ "${CODEX_AUTH_FILE}" == "${_CODEX_AUTH_FILE_FALLBACK}" && ! -f "${_CODEX_AUTH_FILE_FALLBACK}" && -f "${_CODEX_AUTH_FILE_PRIMARY}" ]]; then
  CODEX_AUTH_FILE="${_CODEX_AUTH_FILE_PRIMARY}"
fi
typeset -gr CODEX_AUTH_FILE
typeset -g CODEX_OAUTH_CLIENT_ID="${CODEX_OAUTH_CLIENT_ID:-app_EMoamEEZ73f0CkXaXp7hrann}"
typeset -gr CODEX_OAUTH_CLIENT_ID
typeset -gr CODEX_SECRET_CACHE_DIR="${CODEX_SECRET_CACHE_DIR:-${ZSH_CACHE_DIR:-${ZDOTDIR:-$HOME/.config/zsh}/cache}/codex/secrets}"
typeset -g CODEX_SYNC_AUTH_ON_CHANGE_ENABLED="${CODEX_SYNC_AUTH_ON_CHANGE_ENABLED:-true}"

# crl
# Alias for codex-rate-limits.
alias crl='codex-rate-limits'

# _codex_is_truthy
# Return 0 when the value is truthy (1/true/yes/on).
_codex_is_truthy() {
  emulate -L zsh
  setopt localoptions nounset

  local raw="${1-}"
  raw="${raw:l}"
  case "${raw}" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

# _codex_file_sig
# Print a stable signature for a file (for change detection).
_codex_file_sig() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local file="${1-}"
  [[ -n "${file}" && -f "${file}" ]] || return 1

  if zmodload zsh/stat 2>/dev/null; then
    local -a s
    if zstat -A s -- "${file}" 2>/dev/null; then
      # device inode mode nlink uid gid rdev size atime mtime ctime blksize block link
      print -r -- "${s[2]}:${s[8]}:${s[10]}:${s[11]}"
      return 0
    fi
  fi

  local -i mtime=0 size=0
  if mtime="$(stat -f %m -- "${file}" 2>/dev/null)"; then
    size="$(stat -f %z -- "${file}" 2>/dev/null)" || size=0
    print -r -- "${mtime}:${size}"
    return 0
  fi
  if mtime="$(stat -c %Y -- "${file}" 2>/dev/null)"; then
    size="$(stat -c %s -- "${file}" 2>/dev/null)" || size=0
    print -r -- "${mtime}:${size}"
    return 0
  fi

  return 1
}

# _codex_auth_file_sig
# Print a signature for $CODEX_AUTH_FILE (or "missing").
_codex_auth_file_sig() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local sig=''
  if ! sig="$(_codex_file_sig "${CODEX_AUTH_FILE}")"; then
    sig="missing"
  fi
  print -r -- "${sig}"
}

# _codex_write_timestamp
# Write/remove an ISO timestamp sidecar file.
_codex_write_timestamp() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local timestamp_file="$1"
  local iso="${2-}"

  iso="${iso%%$'\n'*}"
  iso="${iso%%$'\r'*}"

  mkdir -p -- "${timestamp_file:h}"
  if [[ -n "${iso}" ]]; then
    print -r -- "${iso}" >| "${timestamp_file}"
  else
    rm -f -- "${timestamp_file}"
  fi
}

# _codex_jwt_payload
# Extract and decode the JWT payload (base64url -> JSON string).
_codex_jwt_payload() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local token="${1-}"
  if [[ -z "${token}" ]]; then
    return 1
  fi

  local payload="${token#*.}"
  payload="${payload%%.*}"
  if [[ -z "${payload}" ]]; then
    return 1
  fi

  payload="$(print -r -- "${payload}" | tr '_-' '/+')" || return 1

  local -i mod=$(( ${#payload} % 4 ))
  if (( mod == 2 )); then
    payload+='=='
  elif (( mod == 3 )); then
    payload+='='
  elif (( mod == 1 )); then
    return 1
  fi

  local decoded=''
  if decoded="$(print -r -- "${payload}" | base64 -d 2>/dev/null)"; then
    print -r -- "${decoded}"
    return 0
  fi
  if decoded="$(print -r -- "${payload}" | base64 -D 2>/dev/null)"; then
    print -r -- "${decoded}"
    return 0
  fi

  return 1
}

# _codex_auth_identity
# Derive a stable identity from an auth JSON file.
_codex_auth_identity() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local json_file="$1"
  local token=''
  token="$(jq -r '.tokens.id_token // empty' "${json_file}" 2>/dev/null)" || token=""
  if [[ -z "${token}" ]]; then
    token="$(jq -r '.tokens.access_token // empty' "${json_file}" 2>/dev/null)" || token=""
  fi
  if [[ -z "${token}" ]]; then
    return 1
  fi

  local payload=''
  payload="$(_codex_jwt_payload "${token}")" || return 1

  local identity=''
  identity="$(
    print -r -- "${payload}" | jq -r '
      .["https://api.openai.com/auth"].chatgpt_user_id
      // .["https://api.openai.com/auth"].user_id
      // .sub
      // .email
      // empty
    ' 2>/dev/null
  )" || identity=""

  if [[ -z "${identity}" ]]; then
    return 1
  fi

  print -r -- "${identity}"
}

# _codex_auth_account_id
# Extract account_id from an auth JSON file.
_codex_auth_account_id() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local json_file="$1"
  [[ -n "${json_file}" && -f "${json_file}" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  local account_id=''
  account_id="$(jq -r '.tokens.account_id // .account_id // empty' "${json_file}" 2>/dev/null)" || account_id=""
  account_id="${account_id%%$'\n'*}"
  account_id="${account_id%%$'\r'*}"
  [[ -n "${account_id}" ]] || return 1

  print -r -- "${account_id}"
}

# _codex_auth_identity_key
# Return an identity key (identity or identity::account_id) for matching secrets.
_codex_auth_identity_key() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local json_file="$1"
  [[ -n "${json_file}" && -f "${json_file}" ]] || return 1

  local identity=''
  if ! identity="$(_codex_auth_identity "${json_file}")"; then
    return 1
  fi

  local account_id='' key=''
  account_id="$(_codex_auth_account_id "${json_file}")" || account_id=""
  key="${identity}"
  if [[ -n "${account_id}" ]]; then
    key="${identity}::${account_id}"
  fi

  [[ -n "${key}" ]] || return 1
  print -r -- "${key}"
}

# codex-show-current-secret
# Print which secret file matches the current $CODEX_AUTH_FILE.
codex-show-current-secret() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset SH_WORD_SPLIT nullglob

  if [[ ! -f "${CODEX_AUTH_FILE}" ]]; then
    print -ru2 -r -- "codex: ${CODEX_AUTH_FILE} not found"
    return 1
  fi

  local auth_key=''
  auth_key="$(_codex_auth_identity_key "${CODEX_AUTH_FILE}")" || auth_key=""

  local auth_hash=''
  if ! auth_hash="$(shasum -a 256 -- "${CODEX_AUTH_FILE}" | awk '{print $1}')"; then
    print -ru2 -r -- "codex: failed to hash ${CODEX_AUTH_FILE}"
    return 1
  fi

  local matched='' match_mode=''
  local secret='' candidate_key='' candidate_hash=''
  for secret in "${CODEX_SECRET_DIR}"/*.json; do
    [[ -f "${secret}" ]] || continue

    if [[ -n "${auth_key}" ]]; then
      candidate_key="$(_codex_auth_identity_key "${secret}")" || candidate_key=""
      if [[ -n "${candidate_key}" && "${candidate_key}" == "${auth_key}" ]]; then
        candidate_hash="$(shasum -a 256 -- "${secret}" | awk '{print $1}')" || candidate_hash=""
        if [[ -z "${candidate_hash}" ]]; then
          print -ru2 -r -- "codex: failed to hash ${secret}"
          return 1
        fi

        matched="${secret##*/}"
        if [[ "${auth_hash}" == "${candidate_hash}" ]]; then
          match_mode="exact"
        else
          match_mode="identity"
        fi
        break
      fi
    fi

    if candidate_hash="$(shasum -a 256 -- "${secret}" | awk '{print $1}')"; then
      if [[ "${auth_hash}" == "${candidate_hash}" ]]; then
        matched="${secret##*/}"
        match_mode="exact"
        break
      fi
    else
      print -ru2 -r -- "codex: failed to hash ${secret}"
      return 1
    fi
  done

  if [[ -n "${matched}" ]]; then
    if [[ "${match_mode}" == "identity" ]]; then
      print -r -- "codex: ${CODEX_AUTH_FILE} matches ${matched} (identity; secret differs)"
    else
      print -r -- "codex: ${CODEX_AUTH_FILE} matches ${matched}"
    fi
    return 0
  fi

  print -r -- "codex: ${CODEX_AUTH_FILE} does not match any known secret"
  return 2
}

# codex-sync-auth-to-secrets
# Sync $CODEX_AUTH_FILE to any matching secret(s) under $CODEX_SECRET_DIR.
codex-sync-auth-to-secrets() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset nullglob

  if [[ ! -f "${CODEX_AUTH_FILE}" ]]; then
    return 0
  fi

  local auth_key=''
  if ! auth_key="$(_codex_auth_identity_key "${CODEX_AUTH_FILE}")"; then
    return 0
  fi

  local auth_last_refresh=''
  auth_last_refresh="$(jq -r '.last_refresh // empty' "${CODEX_AUTH_FILE}" 2>/dev/null)" || auth_last_refresh=""

  local auth_hash=''
  auth_hash="$(shasum -a 256 -- "${CODEX_AUTH_FILE}" | awk '{print $1}')" || return 1

  local secret_file='' secret_key='' secret_hash='' timestamp_file=''
  for secret_file in "${CODEX_SECRET_DIR}"/*.json; do
    [[ -f "${secret_file}" ]] || continue

    if ! secret_key="$(_codex_auth_identity_key "${secret_file}")"; then
      continue
    fi
    if [[ "${secret_key}" != "${auth_key}" ]]; then
      continue
    fi

    secret_hash="$(shasum -a 256 -- "${secret_file}" | awk '{print $1}')" || return 1
    if [[ "${secret_hash}" == "${auth_hash}" ]]; then
      continue
    fi

    cp -f -- "${CODEX_AUTH_FILE}" "${secret_file}" || return 1
    chmod 600 -- "${secret_file}" 2>/dev/null || true

    timestamp_file="${CODEX_SECRET_CACHE_DIR}/${secret_file:t}.timestamp"
    _codex_write_timestamp "${timestamp_file}" "${auth_last_refresh}"
  done

  timestamp_file="${CODEX_SECRET_CACHE_DIR}/${CODEX_AUTH_FILE:t}.timestamp"
  _codex_write_timestamp "${timestamp_file}" "${auth_last_refresh}"
}

# _codex_apply_secret
# Apply a secret file to $CODEX_AUTH_FILE (syncing current auth first when present).
_codex_apply_secret() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset SH_WORD_SPLIT

  local secret_name="$1"

  shift
  local source_file="${CODEX_SECRET_DIR}/${secret_name}"

  if [[ ! -f "${source_file}" ]]; then
    print -ru2 -r -- "codex: secret file ${secret_name} not found"
    return 1
  fi

  if [[ -f "${CODEX_AUTH_FILE}" ]]; then
    codex-sync-auth-to-secrets || {
      print -ru2 -r -- "codex: failed to sync current auth before switching secrets"
      return 1
    }
  fi

  mkdir -p -- "${CODEX_AUTH_FILE:h}"
  cp -f -- "${source_file}" "${CODEX_AUTH_FILE}"

  local iso=''
  iso="$(jq -r '.last_refresh // empty' "${CODEX_AUTH_FILE}" 2>/dev/null)" || iso=""
  _codex_write_timestamp "${CODEX_SECRET_CACHE_DIR}/${CODEX_AUTH_FILE:t}.timestamp" "${iso}"

  print -r -- "codex: applied ${secret_name} to ${CODEX_AUTH_FILE}"
}

# codex-use
# Switch $CODEX_AUTH_FILE to the given secret under $CODEX_SECRET_DIR.
codex-use() {
  emulate -L zsh
  setopt localoptions nounset

  local secret_name="${1-}"
  if (( $# != 1 )) || [[ -z "${secret_name}" ]]; then
    print -ru2 -r -- "codex-use: usage: codex-use <name|name.json>"
    return 64
  fi
  if [[ "${secret_name}" == *'/'* || "${secret_name}" == *'..'* ]]; then
    print -ru2 -r -- "codex-use: invalid secret name: ${secret_name}"
    return 64
  fi
  if [[ "${secret_name}" != *.json ]]; then
    secret_name="${secret_name}.json"
  fi

  _codex_apply_secret "${secret_name}"
}

# codex-refresh-auth
# Refresh OAuth tokens for $CODEX_AUTH_FILE (or a given secret file) via refresh_token.
codex-refresh-auth() {
  emulate -L zsh
  setopt localoptions SH_WORD_SPLIT
  setopt localtraps
  set -u

  local target_file="${CODEX_AUTH_FILE}"
  if (( $# > 0 )); then
    local secret_name="$1"
    shift

    if (( $# > 0 )); then
      print -ru2 -r -- "codex-refresh: usage: codex-refresh-auth [secret.json]"
      return 64
    fi

    if [[ -z "${secret_name}" || "${secret_name}" == *'/'* || "${secret_name}" == *'..'* ]]; then
      print -ru2 -r -- "codex-refresh: invalid secret file name: ${secret_name}"
      return 64
    fi

    target_file="${CODEX_SECRET_DIR}/${secret_name}"
  fi

  if [[ ! -f "${target_file}" ]]; then
    print -ru2 -r -- "codex-refresh: ${target_file} not found"
    return 1
  fi

  local refresh_token
  if ! refresh_token="$(
    jq -er '
      if (.tokens? // {}) | has("refresh_token") then .tokens.refresh_token
      elif has("refresh_token") then .refresh_token
      else empty end
    ' "${target_file}"
  )"; then
    print -ru2 -r -- "codex-refresh: failed to read refresh token from ${target_file}"
    return 2
  fi

  local now_iso tmp_response tmp_out auth_dir cache_dir timestamp_file http_status
  now_iso="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  auth_dir="${target_file:h}"
  mkdir -p -- "${auth_dir}"
  tmp_response="$(mktemp "${auth_dir}/auth.tokens.XXXXXX")"
  tmp_out="$(mktemp "${auth_dir}/auth.json.XXXXXX")"
  trap "rm -f -- ${(qq)tmp_response} ${(qq)tmp_out}" EXIT

  local connect_timeout="${CODEX_REFRESH_AUTH_CURL_CONNECT_TIMEOUT_SECONDS:-2}"
  local max_time="${CODEX_REFRESH_AUTH_CURL_MAX_TIME_SECONDS:-8}"
  [[ -n "${connect_timeout}" && "${connect_timeout}" == <-> ]] || connect_timeout="2"
  [[ -n "${max_time}" && "${max_time}" == <-> ]] || max_time="8"

  if ! http_status="$(
    curl -sS -o "${tmp_response}" -w "%{http_code}" \
      --connect-timeout "${connect_timeout}" \
      --max-time "${max_time}" \
      https://auth.openai.com/oauth/token \
      -H "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "grant_type=refresh_token" \
      --data-urlencode "client_id=${CODEX_OAUTH_CLIENT_ID}" \
      --data-urlencode "refresh_token=${refresh_token}"
  )"; then
    print -ru2 -r -- "codex-refresh: token endpoint request failed for ${target_file}"
    return 3
  fi

  if [[ "${http_status}" != "200" ]]; then
    local error_summary=''
    error_summary="$(
      jq -r '
        if (.error | type) == "object" then
          [(.error.code // empty), (.error.message // empty)]
          | map(select(length > 0))
          | join(": ")
        else
          [(.error // empty), (.error_description // empty)]
          | map(select(length > 0))
          | join(": ")
        end
      ' "${tmp_response}" 2>/dev/null
    )" || error_summary=""
    error_summary="${error_summary//$'\n'/ }"
    error_summary="${error_summary//$'\r'/ }"

    if [[ -n "${error_summary}" ]]; then
      print -ru2 -r -- "codex-refresh: token endpoint failed (HTTP ${http_status}) for ${target_file}: ${error_summary}"
    else
      print -ru2 -r -- "codex-refresh: token endpoint failed (HTTP ${http_status}) for ${target_file}"
    fi
    return 3
  fi

  if ! jq -e '.' "${tmp_response}" >/dev/null; then
    print -ru2 -r -- "codex-refresh: token endpoint returned invalid JSON"
    return 4
  fi

  if ! jq --slurpfile tokens "${tmp_response}" --arg now "${now_iso}" \
      '.tokens = ((.tokens // {}) + ($tokens[0] // {})) | .last_refresh = $now' \
      "${target_file}" > "${tmp_out}"; then
    print -ru2 -r -- "codex-refresh: failed to merge refreshed tokens"
    return 5
  fi

  mv -f -- "${tmp_out}" "${target_file}"

  cache_dir="${CODEX_SECRET_CACHE_DIR}"
  mkdir -p -- "${cache_dir}"
  timestamp_file="${cache_dir}/${target_file:t}.timestamp"
  _codex_write_timestamp "${timestamp_file}" "${now_iso}"

  if [[ "${target_file}" == "${CODEX_AUTH_FILE}" ]]; then
    codex-sync-auth-to-secrets || return 6
  fi

  print -r -- "codex: refreshed ${target_file} at ${now_iso}"
}

# _codex_sync_auth_on_change
# Sync auth-to-secrets when $CODEX_AUTH_FILE content changes (precmd helper).
_codex_sync_auth_on_change() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  _codex_is_truthy "${CODEX_SYNC_AUTH_ON_CHANGE_ENABLED-}" || return 0

  local sig=''
  sig="$(_codex_auth_file_sig)" || return 0
  if [[ -n "${_CODEX_AUTH_FILES_SIG-}" && "${sig}" == "${_CODEX_AUTH_FILES_SIG}" ]]; then
    return 0
  fi

  codex-sync-auth-to-secrets || true

  sig="$(_codex_auth_file_sig)" || true
  typeset -g _CODEX_AUTH_FILES_SIG="${sig}"
}

# _codex_epoch_format_local
# Format epoch seconds using local timezone.
_codex_epoch_format_local() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local epoch="${1-}"
  local fmt="${2-%Y-%m-%d %H:%M:%S %Z}"

  if [[ -z "${epoch}" || "${epoch}" != <-> ]]; then
    return 1
  fi

  local formatted=''
  if formatted="$(date -r "${epoch}" "+${fmt}" 2>/dev/null)"; then
    print -r -- "${formatted}"
    return 0
  fi
  if formatted="$(date -d "@${epoch}" "+${fmt}" 2>/dev/null)"; then
    print -r -- "${formatted}"
    return 0
  fi

  return 1
}

# _codex_epoch_format_utc
# Format epoch seconds using UTC.
_codex_epoch_format_utc() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local epoch="${1-}"
  local fmt="${2-%Y-%m-%dT%H:%M:%SZ}"

  if [[ -z "${epoch}" || "${epoch}" != <-> ]]; then
    return 1
  fi

  local formatted=''
  if formatted="$(date -u -r "${epoch}" "+${fmt}" 2>/dev/null)"; then
    print -r -- "${formatted}"
    return 0
  fi
  if formatted="$(date -u -d "@${epoch}" "+${fmt}" 2>/dev/null)"; then
    print -r -- "${formatted}"
    return 0
  fi

  return 1
}

# _codex_format_window_seconds
# Format a rate-limit window duration in seconds (e.g. "1d", "Weekly").
_codex_format_window_seconds() {
  emulate -L zsh
  setopt localoptions nounset

  local raw="${1-}"
  if [[ -z "${raw}" || "${raw}" != <-> ]]; then
    return 1
  fi

  local -i seconds="${raw}"
  if (( seconds <= 0 )); then
    return 1
  fi

  if (( seconds % 604800 == 0 )); then
    local -i weeks=$(( seconds / 604800 ))
    if (( weeks == 1 )); then
      print -r -- "Weekly"
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
}

# _codex_rate_limits_writeback_weekly
# Write weekly reset metadata back into the target secret JSON (best-effort).
_codex_rate_limits_writeback_weekly() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset SH_WORD_SPLIT
  setopt localtraps

  local target_file="${1-}"
  local usage_json_file="${2-}"

  if [[ -z "${target_file}" || -z "${usage_json_file}" ]]; then
    print -ru2 -r -- "_codex_rate_limits_writeback_weekly: missing args"
    return 1
  fi
  if [[ ! -f "${target_file}" ]]; then
    print -ru2 -r -- "_codex_rate_limits_writeback_weekly: target file not found: ${target_file}"
    return 1
  fi
  if [[ ! -f "${usage_json_file}" ]]; then
    print -ru2 -r -- "_codex_rate_limits_writeback_weekly: usage JSON not found: ${usage_json_file}"
    return 1
  fi

  local primary_window_seconds='' primary_reset_at=''
  local secondary_window_seconds='' secondary_reset_at=''

  primary_window_seconds="$(jq -r '.rate_limit.primary_window.limit_window_seconds // empty' "${usage_json_file}" 2>/dev/null)" || primary_window_seconds=""
  primary_reset_at="$(jq -r '.rate_limit.primary_window.reset_at // empty' "${usage_json_file}" 2>/dev/null)" || primary_reset_at=""
  secondary_window_seconds="$(jq -r '.rate_limit.secondary_window.limit_window_seconds // empty' "${usage_json_file}" 2>/dev/null)" || secondary_window_seconds=""
  secondary_reset_at="$(jq -r '.rate_limit.secondary_window.reset_at // empty' "${usage_json_file}" 2>/dev/null)" || secondary_reset_at=""

  primary_window_seconds="${primary_window_seconds%%$'\n'*}"
  primary_window_seconds="${primary_window_seconds%%$'\r'*}"
  primary_reset_at="${primary_reset_at%%$'\n'*}"
  primary_reset_at="${primary_reset_at%%$'\r'*}"
  secondary_window_seconds="${secondary_window_seconds%%$'\n'*}"
  secondary_window_seconds="${secondary_window_seconds%%$'\r'*}"
  secondary_reset_at="${secondary_reset_at%%$'\n'*}"
  secondary_reset_at="${secondary_reset_at%%$'\r'*}"

  local primary_label='Primary' secondary_label='Secondary'
  local formatted=''
  if formatted="$(_codex_format_window_seconds "${primary_window_seconds}")"; then
    primary_label="${formatted}"
  fi
  formatted=''
  if formatted="$(_codex_format_window_seconds "${secondary_window_seconds}")"; then
    secondary_label="${formatted}"
  fi

  local weekly_reset_at_epoch=''
  if [[ "${primary_label}" == "Weekly" ]]; then
    weekly_reset_at_epoch="${primary_reset_at}"
  elif [[ "${secondary_label}" == "Weekly" ]]; then
    weekly_reset_at_epoch="${secondary_reset_at}"
  else
    weekly_reset_at_epoch="${secondary_reset_at}"
  fi

  weekly_reset_at_epoch="${weekly_reset_at_epoch%%$'\n'*}"
  weekly_reset_at_epoch="${weekly_reset_at_epoch%%$'\r'*}"
  if [[ -z "${weekly_reset_at_epoch}" || "${weekly_reset_at_epoch}" != <-> ]]; then
    return 0
  fi

  local weekly_reset_at_iso=''
  weekly_reset_at_iso="$(_codex_epoch_format_utc "${weekly_reset_at_epoch}" "%Y-%m-%dT%H:%M:%SZ")" || return 1

  local fetched_at_iso=''
  fetched_at_iso="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  local tmp_out=''
  tmp_out="$(mktemp "${target_file:h}/rate-limits.writeback.XXXXXX")"
  trap "rm -f -- ${(qq)tmp_out}" EXIT

  if ! jq \
    --arg weekly_reset_at "${weekly_reset_at_iso}" \
    --arg fetched_at "${fetched_at_iso}" \
    --argjson weekly_reset_at_epoch "${weekly_reset_at_epoch}" \
    '
      .codex_rate_limits = (.codex_rate_limits // {}) |
      .codex_rate_limits.weekly_reset_at = $weekly_reset_at |
      .codex_rate_limits.weekly_reset_at_epoch = $weekly_reset_at_epoch |
      .codex_rate_limits.weekly_fetched_at = $fetched_at
    ' "${target_file}" >| "${tmp_out}"; then
    print -ru2 -r -- "_codex_rate_limits_writeback_weekly: failed to update ${target_file}"
    return 1
  fi

  mv -f -- "${tmp_out}" "${target_file}" || return 1
  chmod 600 -- "${target_file}" 2>/dev/null || true
}

# _codex_rate_limits_clear_starship_cache
# Clear codex-starship cache directory under $ZSH_CACHE_DIR (or $ZDOTDIR/cache fallback).
# Usage: _codex_rate_limits_clear_starship_cache
_codex_rate_limits_clear_starship_cache() {
  emulate -L zsh
  setopt localoptions pipe_fail err_return nounset

  typeset cache_root="${ZSH_CACHE_DIR-}"
  if [[ -z "$cache_root" ]]; then
    typeset zdotdir="${ZDOTDIR-}"
    if [[ -z "$zdotdir" ]]; then
      typeset home="${HOME-}"
      [[ -n "$home" ]] || return 1
      zdotdir="$home/.config/zsh"
    fi
    cache_root="$zdotdir/cache"
  fi

  if [[ "${cache_root}" != /* ]]; then
    print -u2 -r -- "codex-rate-limits: refusing to clear cache with non-absolute cache root: ${cache_root}"
    return 1
  fi

  typeset cache_root_abs="${cache_root:a}"
  if [[ -z "${cache_root_abs}" || "${cache_root_abs}" == "/" ]]; then
    print -u2 -r -- "codex-rate-limits: refusing to clear cache with invalid cache root: ${cache_root}"
    return 1
  fi

  typeset cache_dir="${cache_root_abs}/codex/starship-rate-limits"
  if [[ "${cache_dir}" != */codex/starship-rate-limits ]]; then
    print -u2 -r -- "codex-rate-limits: refusing to clear unexpected cache dir: ${cache_dir}"
    return 1
  fi

  [[ -d "$cache_dir" ]] || return 0
  command rm -rf -- "$cache_dir"
  return 0
}

# _codex_rate_limits_starship_cache_key
# Convert a display name into the codex-starship cache key.
# Usage: _codex_rate_limits_starship_cache_key <name>
_codex_rate_limits_starship_cache_key() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local name="${1-}"
  [[ -n "${name}" ]] || return 1

  local key="${name:l}"
  key="${key//[^a-z0-9]/_}"
  key="${key##_}"
  key="${key%%_}"
  [[ -n "${key}" ]] || return 1

  print -r -- "${key}"
  return 0
}

# _codex_rate_limits_starship_cache_dir
# Print the codex-starship cache directory path (absolute).
# Usage: _codex_rate_limits_starship_cache_dir
_codex_rate_limits_starship_cache_dir() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local cache_root="${ZSH_CACHE_DIR-}"
  if [[ -z "${cache_root}" ]]; then
    local zdotdir="${ZDOTDIR-}"
    if [[ -z "${zdotdir}" ]]; then
      local home="${HOME-}"
      [[ -n "${home}" ]] || return 1
      zdotdir="${home}/.config/zsh"
    fi
    cache_root="${zdotdir}/cache"
  fi

  if [[ "${cache_root}" != /* ]]; then
    return 1
  fi

  local cache_root_abs="${cache_root:a}"
  if [[ -z "${cache_root_abs}" || "${cache_root_abs}" == "/" ]]; then
    return 1
  fi

  local cache_dir="${cache_root_abs}/codex/starship-rate-limits"
  if [[ "${cache_dir}" != */codex/starship-rate-limits ]]; then
    return 1
  fi

  print -r -- "${cache_dir}"
  return 0
}

# _codex_rate_limits_starship_secret_name_for_auth
# Resolve a matching secret display name (basename without .json) for an auth file.
# Usage: _codex_rate_limits_starship_secret_name_for_auth <auth_file>
_codex_rate_limits_starship_secret_name_for_auth() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset nullglob

  local auth_file="${1-}"
  [[ -n "${auth_file}" && -f "${auth_file}" ]] || return 1

  local secret_dir="${CODEX_SECRET_DIR-}"
  [[ -n "${secret_dir}" && -d "${secret_dir}" ]] || return 1

  local auth_key=''
  auth_key="$(_codex_auth_identity_key "${auth_file}")" || auth_key=''
  [[ -n "${auth_key}" ]] || return 1

  local secret_file='' candidate_key=''
  for secret_file in "${secret_dir}"/*.json; do
    [[ -f "${secret_file}" ]] || continue
    candidate_key="$(_codex_auth_identity_key "${secret_file}")" || continue
    if [[ "${candidate_key}" == "${auth_key}" ]]; then
      print -r -- "${secret_file:t:r}"
      return 0
    fi
  done

  return 1
}

# _codex_rate_limits_starship_cache_file_for_target
# Print the cache file path for a target auth/secret file.
# Usage: _codex_rate_limits_starship_cache_file_for_target <target_file>
_codex_rate_limits_starship_cache_file_for_target() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local target_file="${1-}"
  [[ -n "${target_file}" && -f "${target_file}" ]] || return 1

  local cache_dir=''
  cache_dir="$(_codex_rate_limits_starship_cache_dir)" || return 1

  local key=''
  if [[ "${target_file}" == "${CODEX_SECRET_DIR}"/* ]]; then
    local display_name="${target_file:t:r}"
    key="$(_codex_rate_limits_starship_cache_key "${display_name}")" || return 1
    print -r -- "${cache_dir}/${key}.kv"
    return 0
  fi

  local secret_name=''
  secret_name="$(_codex_rate_limits_starship_secret_name_for_auth "${target_file}")" || secret_name=''
  if [[ -n "${secret_name}" ]]; then
    key="$(_codex_rate_limits_starship_cache_key "${secret_name}")" || return 1
    print -r -- "${cache_dir}/${key}.kv"
    return 0
  fi

  local auth_hash=''
  auth_hash="$(shasum -a 256 -- "${target_file}" 2>/dev/null | awk '{print $1}')" || return 1
  auth_hash="${auth_hash:l}"
  [[ -n "${auth_hash}" ]] || return 1

  print -r -- "${cache_dir}/auth_${auth_hash}.kv"
  return 0
}

# _codex_rate_limits_print_starship_cached
# Print a one-line summary from the codex-starship cache (no network).
# Usage: _codex_rate_limits_print_starship_cached <target_file>
_codex_rate_limits_print_starship_cached() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local target_file="${1-}"
  [[ -n "${target_file}" && -f "${target_file}" ]] || return 1

  local cache_file=''
  cache_file="$(_codex_rate_limits_starship_cache_file_for_target "${target_file}")" || cache_file=''
  if [[ -z "${cache_file}" || ! -f "${cache_file}" ]]; then
    print -ru2 -r -- "codex-rate-limits: cache not found (run codex-rate-limits without --cached, or codex-starship, to populate): ${cache_file}"
    return 1
  fi

  local fetched_at='' non_weekly_label='' non_weekly_remaining=''
  local weekly_remaining='' weekly_reset_epoch=''

  local kv=''
  while IFS= read -r kv; do
    case "${kv}" in
      fetched_at=*) fetched_at="${kv#fetched_at=}" ;;
      non_weekly_label=*) non_weekly_label="${kv#non_weekly_label=}" ;;
      non_weekly_remaining=*) non_weekly_remaining="${kv#non_weekly_remaining=}" ;;
      weekly_remaining=*) weekly_remaining="${kv#weekly_remaining=}" ;;
      weekly_reset_epoch=*) weekly_reset_epoch="${kv#weekly_reset_epoch=}" ;;
    esac
  done < "${cache_file}" 2>/dev/null || true

  if [[ -z "${non_weekly_label}" || -z "${non_weekly_remaining}" || "${non_weekly_remaining}" != <-> ]]; then
    print -ru2 -r -- "codex-rate-limits: invalid cache (missing non-weekly data): ${cache_file}"
    return 1
  fi
  if [[ -z "${weekly_remaining}" || "${weekly_remaining}" != <-> || -z "${weekly_reset_epoch}" || "${weekly_reset_epoch}" != <-> ]]; then
    print -ru2 -r -- "codex-rate-limits: invalid cache (missing weekly data): ${cache_file}"
    return 1
  fi

  local weekly_reset_iso=''
  weekly_reset_iso="$(_codex_epoch_format_utc "${weekly_reset_epoch}" "%Y-%m-%dT%H:%M:%SZ")" || return 1

  local prefix=''
  if [[ "${target_file}" == "${CODEX_SECRET_DIR}"/* ]]; then
    local display_name="${target_file:t:r}"
    prefix="${display_name} "
  fi

  print -r -- "${prefix}${non_weekly_label}:${non_weekly_remaining}% W:${weekly_remaining}% ${weekly_reset_iso}"
  return 0
}

# _codex_rate_limits_write_starship_cache
# Write a codex-starship cache entry for a target file (auth/secret), based on wham/usage data.
# Usage: _codex_rate_limits_write_starship_cache <target_file> <fetched_at_epoch> <non_weekly_label> <non_weekly_remaining> <weekly_remaining> <weekly_reset_epoch>
_codex_rate_limits_write_starship_cache() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local target_file="${1-}"
  local fetched_at_epoch="${2-}"
  local non_weekly_label="${3-}"
  local non_weekly_remaining="${4-}"
  local weekly_remaining="${5-}"
  local weekly_reset_epoch="${6-}"

  [[ -n "${target_file}" && -f "${target_file}" ]] || return 1
  [[ -n "${fetched_at_epoch}" && "${fetched_at_epoch}" == <-> ]] || return 1
  [[ -n "${non_weekly_label}" && -n "${non_weekly_remaining}" && "${non_weekly_remaining}" == <-> ]] || return 1
  [[ -n "${weekly_remaining}" && "${weekly_remaining}" == <-> ]] || return 1
  [[ -n "${weekly_reset_epoch}" && "${weekly_reset_epoch}" == <-> ]] || return 1

  local cache_file=''
  cache_file="$(_codex_rate_limits_starship_cache_file_for_target "${target_file}")" || cache_file=''
  [[ -n "${cache_file}" ]] || return 1

  mkdir -p -- "${cache_file:h}" >/dev/null 2>&1 || return 1

  local tmp_cache=''
  tmp_cache="$(mktemp "${cache_file}.XXXXXX" 2>/dev/null)" || tmp_cache=''
  [[ -n "${tmp_cache}" ]] || return 1

  {
    print -r -- "fetched_at=${fetched_at_epoch}"
    print -r -- "non_weekly_label=${non_weekly_label}"
    print -r -- "non_weekly_remaining=${non_weekly_remaining}"
    print -r -- "weekly_remaining=${weekly_remaining}"
    print -r -- "weekly_reset_epoch=${weekly_reset_epoch}"
  } >| "${tmp_cache}" 2>/dev/null || {
    rm -f -- "${tmp_cache}" 2>/dev/null || true
    return 1
  }

  mv -f -- "${tmp_cache}" "${cache_file}" 2>/dev/null || {
    rm -f -- "${tmp_cache}" 2>/dev/null || true
    return 1
  }

  return 0
}

# codex-rate-limits
# Show Codex rate limits for the active auth file (or secrets under $CODEX_SECRET_DIR).
codex-rate-limits() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset SH_WORD_SPLIT
  setopt localtraps

  local output_mode="human"
  local all_mode="false"
  local one_line="false"
  local clear_starship_cache="false"
  local debug_mode="false"
  local refresh_auth_on_401="true"
  local cached_mode="false"

  while (( $# > 0 )); do
    case "${1-}" in
      -h|--help)
        print -r -- "codex-rate-limits: usage: codex-rate-limits [-c] [-d] [--cached] [--no-refresh-auth] [--json] [--one-line] [--all] [secret.json]"
        print -r -- '  -c                 Clear codex-starship cache ($ZSH_CACHE_DIR/codex/starship-rate-limits) before querying'
        print -r -- '  -d, --debug        Keep stderr and show per-account errors in --all mode (also enabled with ZSH_DEBUG>=1)'
        print -r -- '  --cached           Print cached one-line output from codex-starship cache (no network; implies --one-line)'
        print -r -- '  --no-refresh-auth  Do not refresh auth tokens on HTTP 401 (no retry)'
        print -r -- "  --json             Print raw wham/usage JSON (single account only)"
        print -r -- "  --one-line         Print a single-line summary (single account only; implied by --all)"
        print -r -- "  --all              Query all secrets under CODEX_SECRET_DIR (one line per account)"
        print -r -- "Env:"
        print -r -- "  CODEX_RATE_LIMITS_DEFAULT_ALL=true  Default to --all when no args are provided"
        print -r -- "  CODEX_RATE_LIMITS_CURL_CONNECT_TIMEOUT_SECONDS=2  curl --connect-timeout seconds"
        print -r -- "  CODEX_RATE_LIMITS_CURL_MAX_TIME_SECONDS=8  curl --max-time seconds"
        return 0
        ;;
      -c)
        clear_starship_cache="true"
        shift
        ;;
      -d|--debug)
        debug_mode="true"
        shift
        ;;
      --cached)
        cached_mode="true"
        shift
        ;;
      --no-refresh-auth)
        refresh_auth_on_401="false"
        shift
        ;;
      --json)
        output_mode="json"
        shift
        ;;
      --one-line)
        one_line="true"
        shift
        ;;
      --all)
        all_mode="true"
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        print -ru2 -r -- "codex-rate-limits: unknown option: ${1-}"
        print -ru2 -r -- "codex-rate-limits: usage: codex-rate-limits [-c] [-d] [--cached] [--no-refresh-auth] [--json] [--one-line] [--all] [secret.json]"
        return 64
        ;;
      *)
        break
        ;;
    esac
  done

  if [[ "${cached_mode}" == "true" ]]; then
    one_line="true"
    if [[ "${output_mode}" == "json" ]]; then
      print -ru2 -r -- "codex-rate-limits: --json is not supported with --cached"
      return 64
    fi
    if [[ "${clear_starship_cache}" == "true" ]]; then
      print -ru2 -r -- "codex-rate-limits: -c is not compatible with --cached"
      return 64
    fi
  fi

  if [[ "${debug_mode}" != "true" ]]; then
    local zsh_debug_raw="${ZSH_DEBUG:-0}"
    if [[ "${zsh_debug_raw}" == <-> ]] && (( zsh_debug_raw >= 1 )); then
      debug_mode="true"
    fi
  fi

  if [[ "$clear_starship_cache" == "true" ]]; then
    _codex_rate_limits_clear_starship_cache || return 1
  fi

  if [[ "${output_mode}" == "human" && "${all_mode}" != "true" && $# -eq 0 ]]; then
    local default_all_raw="${CODEX_RATE_LIMITS_DEFAULT_ALL-}"
    default_all_raw="${default_all_raw:l}"
    case "${default_all_raw}" in
      1|true|yes|on) all_mode="true" ;;
      *) ;;
    esac
  fi

  if [[ "${all_mode}" == "true" ]]; then
    one_line="true"

    if [[ "${output_mode}" == "json" ]]; then
      print -ru2 -r -- "codex-rate-limits: --json is not supported with --all"
      return 64
    fi
    if (( $# > 0 )); then
      print -ru2 -r -- "codex-rate-limits: usage: codex-rate-limits [-c] [-d] [--cached] [--no-refresh-auth] [--json] [--one-line] [--all] [secret.json]"
      return 64
    fi

    local secret_dir="${CODEX_SECRET_DIR}"
    if [[ -z "${secret_dir}" || ! -d "${secret_dir}" ]]; then
      print -ru2 -r -- "codex-rate-limits: CODEX_SECRET_DIR not found: ${secret_dir}"
      return 1
    fi

    local -a secret_files
    secret_files=("${secret_dir}"/*.json(N))
    if (( ${#secret_files} == 0 )); then
      print -ru2 -r -- "codex-rate-limits: no secrets found in ${secret_dir}"
      return 1
    fi

    print "\n🚦 Codex rate limits for all accounts"
    print

    local -i rc=0
    local tab=$'\t'
    local -A window_labels=()
    local -a rows=()
    local -a per_secret_args=()
    local secret_file='' secret_name='' line=''

    for secret_file in "${secret_files[@]}"; do
      secret_name="${secret_file:t}"

      per_secret_args=( --one-line )
      if [[ "${cached_mode}" == "true" ]]; then
        per_secret_args+=( --cached )
      fi
      if [[ "${refresh_auth_on_401}" != "true" ]]; then
        per_secret_args+=( --no-refresh-auth )
      fi
      if [[ "${debug_mode}" == "true" ]]; then
        per_secret_args+=( --debug )
      fi

      if [[ "${debug_mode}" == "true" ]]; then
        if ! line="$(codex-rate-limits "${per_secret_args[@]}" "${secret_name}")"; then
          line=''
        fi
      else
        if ! line="$(codex-rate-limits "${per_secret_args[@]}" "${secret_name}" 2>/dev/null)"; then
          line=''
        fi
      fi

      if [[ -z "${line}" ]]; then
        if [[ "${cached_mode}" == "true" ]]; then
          rows+=("${secret_file:t:r}${tab}-${tab}-${tab}-${tab}-")
        else
          rows+=("${secret_file:t:r}${tab}-${tab}-${tab}-${tab}-")
          rc=1
        fi
        continue
      fi

      local parsed_name='' window_field='' weekly_field='' reset_iso=''
      IFS=' ' read -r parsed_name window_field weekly_field reset_iso <<< "${line}"
      if [[ -z "${parsed_name}" || -z "${window_field}" || -z "${weekly_field}" || -z "${reset_iso}" ]]; then
        rows+=("${secret_file:t:r}${tab}-${tab}-${tab}-${tab}-")
        rc=1
        continue
      fi

      local window_label='' non_weekly_remaining='' weekly_remaining=''
      window_label="${window_field%%:*}"
      window_label="${window_label#\"}"
      window_label="${window_label%\"}"
      non_weekly_remaining="${window_field#*:}"
      weekly_remaining="${weekly_field#W:}"

      if [[ -z "${window_label}" || -z "${non_weekly_remaining}" || -z "${weekly_remaining}" ]]; then
        rows+=("${secret_file:t:r}${tab}-${tab}-${tab}-${tab}-")
        rc=1
        continue
      fi

      window_labels["${window_label}"]=1
      rows+=("${parsed_name}${tab}${window_label}${tab}${non_weekly_remaining}${tab}${weekly_remaining}${tab}${reset_iso}")
    done

    local non_weekly_header="Non-weekly"
    if (( ${#window_labels[@]} == 1 )); then
      local only_label=''
      for only_label in "${(@k)window_labels}"; do
        non_weekly_header="${only_label}"
      done
    fi
    non_weekly_header="${non_weekly_header#\"}"
    non_weekly_header="${non_weekly_header%\"}"

    printf "%-25.25s %8.8s %8.8s  %-20.20s\n" "Name" "${non_weekly_header}" "Weekly" "Reset (UTC)"
    print -r -- "-----------------------------------------------------------------------"

    local row='' row_name='' row_window='' row_remain='' row_weekly='' row_reset='' display_non_weekly=''
    for row in "${rows[@]}"; do
      IFS=$'\t' read -r row_name row_window row_remain row_weekly row_reset <<< "${row}"
      display_non_weekly="${row_remain}"
      if (( ${#window_labels[@]} != 1 )) && [[ -n "${row_window}" && "${row_window}" != '-' && -n "${row_remain}" && "${row_remain}" != '-' ]]; then
        display_non_weekly="${row_window}:${row_remain}"
      fi
      printf "%-25.25s %8.8s %8.8s  %-20.20s\n" "${row_name}" "${display_non_weekly}" "${row_weekly}" "${row_reset}"
    done

    return "${rc}"
  fi

  if [[ "${output_mode}" == "json" && "${one_line}" == "true" ]]; then
    print -ru2 -r -- "codex-rate-limits: --one-line is not compatible with --json"
    return 64
  fi

  local target_file="${CODEX_AUTH_FILE}"
  if (( $# > 0 )); then
    local secret_name="${1-}"
    shift

    if (( $# > 0 )); then
      print -ru2 -r -- "codex-rate-limits: usage: codex-rate-limits [-c] [-d] [--cached] [--no-refresh-auth] [--json] [--one-line] [--all] [secret.json]"
      return 64
    fi
    if [[ -z "${secret_name}" || "${secret_name}" == *'/'* || "${secret_name}" == *'..'* ]]; then
      print -ru2 -r -- "codex-rate-limits: invalid secret file name: ${secret_name}"
      return 64
    fi
    target_file="${CODEX_SECRET_DIR}/${secret_name}"
  fi

  if [[ ! -f "${target_file}" ]]; then
    print -ru2 -r -- "codex-rate-limits: ${target_file} not found"
    return 1
  fi

  if [[ "${cached_mode}" == "true" ]]; then
    _codex_rate_limits_print_starship_cached "${target_file}" || return 1
    return 0
  fi

  local access_token='' account_id=''
  access_token="$(jq -r '.tokens.access_token // empty' "${target_file}" 2>/dev/null)" || access_token=""
  account_id="$(jq -r '.tokens.account_id // empty' "${target_file}" 2>/dev/null)" || account_id=""
  if [[ -z "${access_token}" ]]; then
    print -ru2 -r -- "codex-rate-limits: missing access_token in ${target_file}"
    return 2
  fi

  local base_url="${CODEX_CHATGPT_BASE_URL:-https://chatgpt.com/backend-api/}"
  base_url="${base_url%/}"
  local url="${base_url}/wham/usage"

  local connect_timeout="${CODEX_RATE_LIMITS_CURL_CONNECT_TIMEOUT_SECONDS:-2}"
  local max_time="${CODEX_RATE_LIMITS_CURL_MAX_TIME_SECONDS:-8}"
  [[ -n "${connect_timeout}" && "${connect_timeout}" == <-> ]] || connect_timeout="2"
  [[ -n "${max_time}" && "${max_time}" == <-> ]] || max_time="8"

  local tmp_response http_status
  tmp_response="$(mktemp "${target_file:h}/wham.usage.XXXXXX")"
  trap "rm -f -- ${(qq)tmp_response}" EXIT

  local -a curl_args
  curl_args=(
    -sS
    -o "${tmp_response}"
    -w "%{http_code}"
    --connect-timeout "${connect_timeout}"
    --max-time "${max_time}"
    "${url}"
    -H "Authorization: Bearer ${access_token}"
    -H "Accept: application/json"
    -H "User-Agent: codex-cli"
  )
  if [[ -n "${account_id}" ]]; then
    curl_args+=( -H "ChatGPT-Account-Id: ${account_id}" )
  fi

  if ! http_status="$(curl "${curl_args[@]}")"; then
    print -ru2 -r -- "codex-rate-limits: request failed: ${url}"
    return 3
  fi

  if [[ "${http_status}" == "401" && "${refresh_auth_on_401}" == "true" ]]; then
    if [[ "${target_file}" == "${CODEX_AUTH_FILE}" ]]; then
      codex-refresh-auth >/dev/null || true
    else
      codex-refresh-auth "${target_file:t}" >/dev/null || true
    fi

      access_token="$(jq -r '.tokens.access_token // empty' "${target_file}" 2>/dev/null)" || access_token=""
      account_id="$(jq -r '.tokens.account_id // empty' "${target_file}" 2>/dev/null)" || account_id=""
      if [[ -n "${access_token}" ]]; then
        curl_args=(
          -sS
          -o "${tmp_response}"
          -w "%{http_code}"
          --connect-timeout "${connect_timeout}"
          --max-time "${max_time}"
          "${url}"
          -H "Authorization: Bearer ${access_token}"
          -H "Accept: application/json"
          -H "User-Agent: codex-cli"
        )
        if [[ -n "${account_id}" ]]; then
          curl_args+=( -H "ChatGPT-Account-Id: ${account_id}" )
        fi
        http_status="$(curl "${curl_args[@]}")" || true
      fi
  fi

  if [[ "${http_status}" != "200" ]]; then
    local preview=''
    preview="$(head -c 200 "${tmp_response}" 2>/dev/null | tr '\n' ' ' | tr '\r' ' ')" || preview=""
    print -ru2 -r -- "codex-rate-limits: GET ${url} failed (HTTP ${http_status})"
    if [[ -n "${preview}" ]]; then
      print -ru2 -r -- "codex-rate-limits: body: ${preview}"
    fi
    return 3
  fi

  _codex_rate_limits_writeback_weekly "${target_file}" "${tmp_response}" || return 4
  if [[ "${target_file}" == "${CODEX_AUTH_FILE}" ]]; then
    codex-sync-auth-to-secrets || return 5
  fi

  if [[ "${output_mode}" == "json" ]]; then
    cat -- "${tmp_response}"
    return 0
  fi

  local primary_window_seconds='' primary_remaining='' primary_reset_at=''
  local secondary_window_seconds='' secondary_remaining='' secondary_reset_at=''

  primary_window_seconds="$(jq -r '.rate_limit.primary_window.limit_window_seconds // empty' "${tmp_response}" 2>/dev/null)" || primary_window_seconds=""
  primary_remaining="$(jq -r '(100 - (.rate_limit.primary_window.used_percent // 0)) | round' "${tmp_response}" 2>/dev/null)" || primary_remaining=""
  primary_reset_at="$(jq -r '.rate_limit.primary_window.reset_at // empty' "${tmp_response}" 2>/dev/null)" || primary_reset_at=""

  secondary_window_seconds="$(jq -r '.rate_limit.secondary_window.limit_window_seconds // empty' "${tmp_response}" 2>/dev/null)" || secondary_window_seconds=""
  secondary_remaining="$(jq -r '(100 - (.rate_limit.secondary_window.used_percent // 0)) | round' "${tmp_response}" 2>/dev/null)" || secondary_remaining=""
  secondary_reset_at="$(jq -r '.rate_limit.secondary_window.reset_at // empty' "${tmp_response}" 2>/dev/null)" || secondary_reset_at=""

  local primary_label="Primary" secondary_label="Secondary"
  local formatted=''
  if formatted="$(_codex_format_window_seconds "${primary_window_seconds}")"; then
    primary_label="${formatted}"
  fi
  formatted=''
  if formatted="$(_codex_format_window_seconds "${secondary_window_seconds}")"; then
    secondary_label="${formatted}"
  fi

  local fetched_at_epoch=''
  fetched_at_epoch="$(date +%s 2>/dev/null)" || fetched_at_epoch=''
  if [[ -n "${fetched_at_epoch}" && "${fetched_at_epoch}" == <-> ]]; then
    local weekly_remaining='' weekly_reset_epoch=''
    local non_weekly_label='' non_weekly_remaining=''

    if [[ "${primary_label}" == "Weekly" ]]; then
      weekly_remaining="${primary_remaining}"
      weekly_reset_epoch="${primary_reset_at}"
      non_weekly_label="${secondary_label}"
      non_weekly_remaining="${secondary_remaining}"
    elif [[ "${secondary_label}" == "Weekly" ]]; then
      weekly_remaining="${secondary_remaining}"
      weekly_reset_epoch="${secondary_reset_at}"
      non_weekly_label="${primary_label}"
      non_weekly_remaining="${primary_remaining}"
    else
      weekly_remaining="${secondary_remaining}"
      weekly_reset_epoch="${secondary_reset_at}"
      non_weekly_label="${primary_label}"
      non_weekly_remaining="${primary_remaining}"
    fi

    _codex_rate_limits_write_starship_cache \
      "${target_file}" \
      "${fetched_at_epoch}" \
      "${non_weekly_label}" \
      "${non_weekly_remaining}" \
      "${weekly_remaining}" \
      "${weekly_reset_epoch}" \
      >/dev/null 2>&1 || true
  fi

  local primary_reset_time="?" secondary_reset_date="?"
  primary_reset_time="$(_codex_epoch_format_local "${primary_reset_at}" "%I:%M %p")" || primary_reset_time="?"
  primary_reset_time="${primary_reset_time#0}"

  secondary_reset_date="$(_codex_epoch_format_local "${secondary_reset_at}" "%b %e")" || secondary_reset_date="?"
  secondary_reset_date="${secondary_reset_date//  / }"
  secondary_reset_date="${secondary_reset_date# }"

  local primary_reset_iso="?" secondary_reset_iso="?"
  primary_reset_iso="$(_codex_epoch_format_utc "${primary_reset_at}" "%Y-%m-%dT%H:%M:%SZ")" || primary_reset_iso="?"
  secondary_reset_iso="$(_codex_epoch_format_utc "${secondary_reset_at}" "%Y-%m-%dT%H:%M:%SZ")" || secondary_reset_iso="?"

  if [[ "${one_line}" == "true" ]]; then
    local display_name=''
    if [[ "${target_file}" == "${CODEX_SECRET_DIR}"/* ]]; then
      display_name="${target_file:t:r}"
    fi

    local weekly_remaining='' weekly_reset_iso=''
    local non_weekly_label='' non_weekly_remaining=''
    if [[ "${primary_label}" == "Weekly" ]]; then
      weekly_remaining="${primary_remaining}"
      weekly_reset_iso="${primary_reset_iso}"
      non_weekly_label="${secondary_label}"
      non_weekly_remaining="${secondary_remaining}"
    elif [[ "${secondary_label}" == "Weekly" ]]; then
      weekly_remaining="${secondary_remaining}"
      weekly_reset_iso="${secondary_reset_iso}"
      non_weekly_label="${primary_label}"
      non_weekly_remaining="${primary_remaining}"
    else
      weekly_remaining="${secondary_remaining}"
      weekly_reset_iso="${secondary_reset_iso}"
      non_weekly_label="${primary_label}"
      non_weekly_remaining="${primary_remaining}"
    fi

    local prefix=''
    if [[ -n "${display_name}" ]]; then
      prefix="${display_name} "
    fi

    print -r -- "${prefix}${non_weekly_label}:${non_weekly_remaining}% W:${weekly_remaining}% ${weekly_reset_iso}"
    return 0
  fi

  print -r -- "Rate limits remaining"
  print -r -- "${primary_label} ${primary_remaining}% • ${primary_reset_iso}"
  print -r -- "${secondary_label} ${secondary_remaining}% • ${secondary_reset_iso}"
}

if [[ -o interactive ]]; then
  if [[ -z "${_CODEX_AUTH_SYNC_HOOK_INSTALLED-}" ]]; then
    typeset -gr _CODEX_AUTH_SYNC_HOOK_INSTALLED=1

    autoload -Uz add-zsh-hook 2>/dev/null || true
    if typeset -f add-zsh-hook >/dev/null 2>&1; then
      # _codex_auth_sync_precmd
      # Interactive precmd hook to keep secrets synced on auth changes.
      _codex_auth_sync_precmd() {
        emulate -L zsh
        setopt localoptions pipe_fail nounset

        _codex_sync_auth_on_change || true
        return 0
      }
      add-zsh-hook precmd _codex_auth_sync_precmd
    fi
  fi
fi
