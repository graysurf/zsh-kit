#!/usr/bin/env -S zsh -f

if [[ -z ${_codex_auto_refresh_file-} ]]; then
  typeset -gr _codex_auto_refresh_file="${${(%):-%x}:A}"
fi
if [[ -z ${_codex_auto_refresh_dir-} ]]; then
  typeset -gr _codex_auto_refresh_dir="${_codex_auto_refresh_file:h}"
fi

typeset -g CODEX_AUTO_REFRESH_MIN_DAYS="${CODEX_AUTO_REFRESH_MIN_DAYS:-5}"
typeset -g CODEX_AUTO_REFRESH_ENABLED="${CODEX_AUTO_REFRESH_ENABLED:-false}"

# _codex_auto_refresh_secrets_dir
# Print the secrets directory path (feature-local), based on this script location.
_codex_auto_refresh_secrets_dir() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  typeset feature_dir="${_codex_auto_refresh_dir-}"
  [[ -n "$feature_dir" ]] || return 1

  typeset secrets_dir="$feature_dir/secrets"
  [[ -d "$secrets_dir" ]] || return 1

  print -r -- "$secrets_dir"
  return 0
}

# _codex_auto_refresh_is_enabled
# Return 0 when auto-refresh is enabled via CODEX_AUTO_REFRESH_ENABLED.
_codex_auto_refresh_is_enabled() {
  emulate -L zsh
  setopt localoptions nounset

  typeset raw="${CODEX_AUTO_REFRESH_ENABLED-}"
  zsh_env::is_true "$raw" "CODEX_AUTO_REFRESH_ENABLED"
}

# _codex_auto_refresh_is_configured
# Return 0 when Codex auth/profiles exist; otherwise treat as "not configured" and stay quiet.
_codex_auto_refresh_is_configured() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset nullglob

  typeset home="${HOME-}"
  [[ -n "$home" ]] || return 1

  typeset secrets_dir=''
  secrets_dir="$(_codex_auto_refresh_secrets_dir 2>/dev/null)" || secrets_dir=''

  typeset -a candidates=(
    "$home/.config/codex-kit/auth.json"
    "$home/.codex/auth.json"
  )
  [[ -n "$secrets_dir" ]] && candidates+=("$secrets_dir"/*.json)

  typeset file=''
  for file in "${candidates[@]}"; do
    [[ -f "$file" ]] && return 0
  done

  return 1
}

# _codex_auto_refresh_require_codex
# Ensure codex-refresh-auth is available (lazy-load secrets module if needed).
_codex_auto_refresh_require_codex() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  if typeset -f codex-refresh-auth >/dev/null 2>&1 \
      && [[ -n "${CODEX_AUTH_FILE-}" && -n "${CODEX_SECRET_DIR-}" && -n "${CODEX_SECRET_CACHE_DIR-}" ]]; then
    return 0
  fi

  typeset secrets_dir=''
  secrets_dir="$(_codex_auto_refresh_secrets_dir 2>/dev/null)" || secrets_dir=''
  if [[ -z "$secrets_dir" ]]; then
    print -u2 -r -- "codex-auto-refresh: secrets dir not found (expected: ${_codex_auto_refresh_dir}/secrets)"
    return 1
  fi

  source "$secrets_dir/_codex-secret.zsh"

  if ! typeset -f codex-refresh-auth >/dev/null 2>&1 \
      || [[ -z "${CODEX_AUTH_FILE-}" || -z "${CODEX_SECRET_DIR-}" || -z "${CODEX_SECRET_CACHE_DIR-}" ]]; then
    print -u2 -r -- "codex-auto-refresh: failed to load codex-refresh-auth"
    return 1
  fi
}

# _codex_auto_refresh_normalize_iso
# Normalize ISO timestamp strings (strip CR/LF; drop fractional seconds).
_codex_auto_refresh_normalize_iso() {
  emulate -L zsh
  setopt localoptions nounset

  local iso="${1}"
  iso="${iso%%$'\n'*}"
  iso="${iso%%$'\r'*}"
  if [[ -n "${iso}" && "${iso}" == *.*Z ]]; then
    iso="${iso%%.*}Z"
  fi
  print -r -- "${iso}"
}

# _codex_auto_refresh_iso_to_epoch
# Convert an ISO timestamp (UTC) to epoch seconds (macOS/GNU date compatible).
_codex_auto_refresh_iso_to_epoch() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local iso="${1}"
  local epoch=''

  if epoch="$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "${iso}" "+%s" 2>/dev/null)"; then
    print -r -- "${epoch}"
    return 0
  fi

  if epoch="$(date -u -d "${iso}" "+%s" 2>/dev/null)"; then
    print -r -- "${epoch}"
    return 0
  fi

  return 1
}

# _codex_auto_refresh_last_refresh_epoch
# Read last refresh epoch seconds from timestamp file or auth JSON (and backfill timestamp).
_codex_auto_refresh_last_refresh_epoch() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local target_file="$1"
  local timestamp_file="$2"

  local iso='' epoch=''
  local -i timestamp_missing_or_invalid=0
  if [[ -f "${timestamp_file}" ]]; then
    iso="$(_codex_auto_refresh_normalize_iso "$(<"${timestamp_file}")")"
    if [[ -n "${iso}" ]] && epoch="$(_codex_auto_refresh_iso_to_epoch "${iso}")"; then
      print -r -- "${epoch}"
      return 0
    fi
    timestamp_missing_or_invalid=1
  else
    timestamp_missing_or_invalid=1
  fi

  iso="$(jq -r '.last_refresh // empty' "${target_file}" 2>/dev/null)" || iso=""
  iso="$(_codex_auto_refresh_normalize_iso "${iso}")"
  if [[ -n "${iso}" ]] && epoch="$(_codex_auto_refresh_iso_to_epoch "${iso}")"; then
    if (( timestamp_missing_or_invalid )); then
      mkdir -p -- "${timestamp_file:h}"
      print -r -- "${iso}" >| "${timestamp_file}"
    fi
    print -r -- "${epoch}"
    return 0
  fi

  return 1
}

# _codex_auto_refresh_should_refresh
# Return 0 when the target is older than min_seconds (or missing timestamp).
_codex_auto_refresh_should_refresh() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset

  local target_file="$1"
  local timestamp_file="$2"
  local -i now_epoch="$3"
  local -i min_seconds="$4"

  local last_epoch=''
  if last_epoch="$(_codex_auto_refresh_last_refresh_epoch "${target_file}" "${timestamp_file}")"; then
    local -i age_seconds=$(( now_epoch - last_epoch ))
    if (( age_seconds < 0 )); then
      print -u2 -r -- "codex-auto-refresh: warning: future timestamp for ${target_file}"
      return 1
    fi

    if (( age_seconds >= min_seconds )); then
      return 0
    fi
    return 1
  fi

  return 0
}

# _codex_auto_refresh_main
# Refresh auth/secrets when stale; prints summary when run as script or when changes occur.
_codex_auto_refresh_main() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset no_aliases nullglob

  _codex_auto_refresh_is_configured || return 0
  _codex_auto_refresh_require_codex || return 1

  if typeset -f codex-sync-auth-to-secrets >/dev/null 2>&1; then
    codex-sync-auth-to-secrets || return 1
  fi

  if (( $# > 0 )); then
    print -u2 -r -- "usage: ${_codex_auto_refresh_file:t}"
    return 64
  fi

  local min_days_raw="${CODEX_AUTO_REFRESH_MIN_DAYS}"
  if [[ -z "${min_days_raw}" || "${min_days_raw}" != <-> ]]; then
    print -u2 -r -- "codex-auto-refresh: invalid CODEX_AUTO_REFRESH_MIN_DAYS: ${min_days_raw}"
    return 64
  fi

  local -i min_days="${min_days_raw}"
  local -i min_seconds=$(( min_days * 86400 ))
  local -i now_epoch=0
  now_epoch="$(date -u +%s)"

  local -a targets=()
  targets=( "${CODEX_AUTH_FILE}" "${CODEX_SECRET_DIR}"/*.json )

  local -i refreshed=0 skipped=0 failures=0
  local target_file='' base='' timestamp_file=''
  for target_file in "${targets[@]}"; do
    if [[ ! -f "${target_file}" ]]; then
      if [[ "${target_file}" == "${CODEX_AUTH_FILE}" ]]; then
        (( skipped++ ))
        continue
      fi

      print -u2 -r -- "codex-auto-refresh: missing file: ${target_file}"
      (( failures++ ))
      continue
    fi

    base="${target_file:t}"
    timestamp_file="${CODEX_SECRET_CACHE_DIR}/${base}.timestamp"

    if ! _codex_auto_refresh_should_refresh "${target_file}" "${timestamp_file}" "${now_epoch}" "${min_seconds}"; then
      (( skipped++ ))
      continue
    fi

    if [[ "${target_file}" == "${CODEX_AUTH_FILE}" ]]; then
      if codex-refresh-auth; then
        (( refreshed++ ))
      else
        (( failures++ ))
      fi
      continue
    fi

    if codex-refresh-auth "${base}"; then
      (( refreshed++ ))
    else
      (( failures++ ))
    fi
  done

  local -i ran_as_script=0
  if [[ "${ZSH_ARGZERO:A}" == "${_codex_auto_refresh_file}" ]]; then
    ran_as_script=1
  fi

  if (( ran_as_script || refreshed > 0 || failures > 0 )); then
    print -r -- "codex-auto-refresh: refreshed=${refreshed} skipped=${skipped} failed=${failures} (min_age_days=${min_days})"
  fi
  if (( failures > 0 )); then
    return 1
  fi
}

# codex-auto-refresh
# Public entrypoint wrapper around _codex_auto_refresh_main.
codex-auto-refresh() {
  emulate -L zsh
  setopt localoptions pipe_fail nounset
  _codex_auto_refresh_main "$@"
}

if [[ "${ZSH_ARGZERO:A}" == "${_codex_auto_refresh_file}" ]]; then
  _codex_auto_refresh_main "$@"
else
  if [[ -z "${_CODEX_AUTO_REFRESH_HOOK_INSTALLED-}" ]]; then
    typeset -gr _CODEX_AUTO_REFRESH_HOOK_INSTALLED=1

    autoload -Uz add-zsh-hook 2>/dev/null || true
    if typeset -f add-zsh-hook >/dev/null 2>&1; then
      # _codex_auto_refresh_precmd
      # One-shot precmd hook to run auto-refresh in interactive shells.
      _codex_auto_refresh_precmd() {
        emulate -L zsh
        setopt localoptions pipe_fail nounset

        add-zsh-hook -d precmd _codex_auto_refresh_precmd 2>/dev/null || true

        _codex_auto_refresh_is_enabled || return 0
        _codex_auto_refresh_main || true
        return 0
      }
      add-zsh-hook precmd _codex_auto_refresh_precmd
    fi
  fi
fi
