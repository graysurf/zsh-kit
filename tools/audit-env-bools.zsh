#!/usr/bin/env -S zsh -f

setopt pipe_fail err_exit nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr SCRIPT_NAME="${SCRIPT_PATH:t}"
typeset -gr SCRIPT_HINT="./tools/$SCRIPT_NAME"

# print_usage: Print CLI usage/help.
print_usage() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -r -- "Usage: $SCRIPT_HINT [--check] [-h|--help]"
  print -r --
  print -r -- "Purpose:"
  print -r -- "  Enforce project boolean env rules for the Inventory flags."
  print -r --
  print -r -- "Checks (Inventory flags):"
  print -r -- "  - No legacy env names in tracked code/docs (excludes docs/progress/*)."
  print -r -- "  - No 0/1/yes/no/on/off assignments (only true|false allowed)."
  print -r -- "  - .private/priv-env.zsh exports use only true|false (if file exists)."
  print -r --
  print -r -- "Examples:"
  print -r -- "  $SCRIPT_HINT --check"
}

# repo_root_from_script: Resolve the repo root directory from this script path.
repo_root_from_script() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset script_dir='' root_dir=''
  script_dir="${SCRIPT_PATH:h}"
  root_dir="${script_dir:h}"
  print -r -- "$root_dir"
}

# list_scan_files <root_dir>
# Print the absolute file paths to scan (tracked files excluding docs/progress; plus .private text files).
list_scan_files() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset root_dir="$1"
  typeset -a files=()
  typeset rel='' file=''

  if command -v git >/dev/null 2>&1 && git -C "$root_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r rel; do
      [[ -n "$rel" ]] || continue

      case "$rel" in
        docs/progress/*) continue ;;
        plugins/*) continue ;;
        out/*) continue ;;
        cache/*) continue ;;
        tools/audit-env-bools.zsh) continue ;;
      esac

      files+=("$root_dir/$rel")
    done < <(git -C "$root_dir" ls-files)
  else
    for file in "$root_dir"/.zshrc(N) "$root_dir"/.zprofile(N) "$root_dir"/.zshenv(N); do
      files+=("$file")
    done
    for file in "$root_dir"/bootstrap/**/*(N.) "$root_dir"/scripts/**/*(N.) "$root_dir"/tools/**/*(N.) "$root_dir"/docs/**/*(N.) "$root_dir"/config/**/*(N.); do
      [[ "$file" == "$root_dir/docs/progress/"* ]] && continue
      [[ "$file" == "$root_dir/plugins/"* ]] && continue
      [[ "$file" == "$root_dir/out/"* ]] && continue
      [[ "$file" == "$root_dir/cache/"* ]] && continue
      [[ "$file" == "$root_dir/tools/audit-env-bools.zsh" ]] && continue
      files+=("$file")
    done
  fi

  if [[ -d "$root_dir/.private" ]]; then
    while IFS= read -r file; do
      [[ -n "$file" ]] && files+=("$file")
    done < <(
      command find "$root_dir/.private" -type f \
        \( -name '*.zsh' -o -name '*.sh' -o -name '*.md' -o -name '*.txt' -o -name '*.toml' -o -name '*.yaml' -o -name '*.yml' \) \
        ! -path "$root_dir/.private/.git/*" \
        -print 2>/dev/null | command sort
    )
  fi

  print -rl -- "${files[@]}"
}

# grep_hits <pattern> <file>
# Print matching lines with line numbers (grep -nE); return 0 when hits exist.
grep_hits() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset pattern="$1"
  typeset file="$2"

  command grep -nE -- "$pattern" "$file" 2>/dev/null
}

# check_no_legacy_names <files...>
# Ensure legacy env names are not referenced (excluding docs/progress which is already excluded from file list).
check_no_legacy_names() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -a files=("$@")
  typeset -a legacy_strict=(
    CODEX_ALLOW_DANGEROUS
    CODEX_DESKTOP_NOTIFY
    CODEX_DESKTOP_NOTIFY_HINTS
    CODEX_RATE_LIMITS_DEFAULT_ALL
    CODEX_STARSHIP_SHOW_5H
    CODEX_STARSHIP_SHOW_FALLBACK_NAME
    ZSH_BOOT_WEATHER
    ZSH_BOOT_QUOTE
    FZF_DEF_DOC_CACHE_ENABLE
    PLUGIN_FETCH_DRY_RUN
    PLUGIN_FETCH_FORCE
    RDP_ASSUME_YES
    RDP_REFRESH_PROFILE
    RDP_DEBUG
    RDP_USE_ISOLATED_PROFILE
    SHELL_UTILS_NO_BUILTIN_OVERRIDES
  )

  # These names are too generic to ban by "mention", so only forbid assignment usage (FLAG=...).
  typeset -a legacy_assignment_only=(
    DRY_RUN
    QUIET
    INCLUDE_OPTIONAL
  )

  typeset -i failed=0
  typeset flag='' file='' hits='' pattern=''

  for flag in "${legacy_strict[@]}"; do
    pattern="(^|[^[:alnum:]_])${flag}([^[:alnum:]_]|$)"
    for file in "${files[@]}"; do
      [[ -r "$file" ]] || continue
      hits="$(grep_hits "$pattern" "$file" || true)"
      [[ -n "$hits" ]] || continue
      failed=1
      print -u2 -r -- "❌ legacy env name referenced: $flag"
      print -u2 -r -- "$file"
      print -u2 -r -- "$hits"
    done
  done

  for flag in "${legacy_assignment_only[@]}"; do
    pattern="(^|[^[:alnum:]_])${flag}[[:space:]]*="
    for file in "${files[@]}"; do
      [[ -r "$file" ]] || continue
      hits="$(grep_hits "$pattern" "$file" || true)"
      [[ -n "$hits" ]] || continue
      failed=1
      print -u2 -r -- "❌ legacy env assignment found: $flag"
      print -u2 -r -- "$file"
      print -u2 -r -- "$hits"
    done
  done

  return "$failed"
}

# check_no_forbidden_values <files...>
# Ensure Inventory flags are never assigned to forbidden boolean vocab (0/1/yes/no/on/off).
check_no_forbidden_values() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -a files=("$@")
  typeset -a inventory_flags=(
    CODEX_ALLOW_DANGEROUS_ENABLED
    CODEX_DESKTOP_NOTIFY_ENABLED
    CODEX_DESKTOP_NOTIFY_HINTS_ENABLED
    CODEX_AUTO_REFRESH_ENABLED
    CODEX_RATE_LIMITS_DEFAULT_ALL_ENABLED
    CODEX_SYNC_AUTH_ON_CHANGE_ENABLED
    CODEX_STARSHIP_ENABLED
    CODEX_STARSHIP_SHOW_5H_ENABLED
    CODEX_STARSHIP_SHOW_FALLBACK_NAME_ENABLED
    ZSH_BOOT_WEATHER_ENABLED
    ZSH_BOOT_QUOTE_ENABLED
    FZF_DEF_DOC_CACHE_ENABLED
    PLUGIN_FETCH_DRY_RUN_ENABLED
    PLUGIN_FETCH_FORCE_ENABLED
    ZSH_INSTALL_TOOLS_DRY_RUN_ENABLED
    ZSH_INSTALL_TOOLS_QUIET_ENABLED
    ZSH_INSTALL_TOOLS_INCLUDE_OPTIONAL_ENABLED
    RDP_ASSUME_YES_ENABLED
    RDP_REFRESH_PROFILE_ENABLED
    RDP_DEBUG_ENABLED
    RDP_USE_ISOLATED_PROFILE_ENABLED
    SHELL_UTILS_BUILTIN_OVERRIDES_ENABLED
  )

  typeset -i failed=0
  typeset flag='' file='' hits='' pattern=''

  for flag in "${inventory_flags[@]}"; do
    pattern="(^|[^[:alnum:]_])${flag}[[:space:]]*=[[:space:]]*['\\\"]?(0|1|yes|no|on|off)['\\\"]?([^[:alnum:]_]|$)"
    for file in "${files[@]}"; do
      [[ -r "$file" ]] || continue
      hits="$(command grep -niE -- "$pattern" "$file" 2>/dev/null || true)"
      [[ -n "$hits" ]] || continue
      failed=1
      print -u2 -r -- "❌ forbidden boolean value for: $flag (only true|false allowed)"
      print -u2 -r -- "$file"
      print -u2 -r -- "$hits"
    done
  done

  return "$failed"
}

# check_private_exports <priv_env_file>
# Ensure .private exports for Inventory flags use only true|false (if present).
check_private_exports() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset priv_env_file="$1"
  [[ -f "$priv_env_file" ]] || return 0

  typeset -a inventory_flags=(
    CODEX_ALLOW_DANGEROUS_ENABLED
    CODEX_DESKTOP_NOTIFY_ENABLED
    CODEX_DESKTOP_NOTIFY_HINTS_ENABLED
    CODEX_AUTO_REFRESH_ENABLED
    CODEX_RATE_LIMITS_DEFAULT_ALL_ENABLED
    CODEX_STARSHIP_ENABLED
    CODEX_STARSHIP_SHOW_5H_ENABLED
    CODEX_STARSHIP_SHOW_FALLBACK_NAME_ENABLED
  )

  typeset -i failed=0
  typeset line='' flag='' raw='' value='' lowered=''

  while IFS= read -r line; do
    for flag in "${inventory_flags[@]}"; do
      if [[ "$line" =~ ('^[[:space:]]*export[[:space:]]+'${flag}'[[:space:]]*=[[:space:]]*([^[:space:]#]+)') ]]; then
        raw="${match[2]}"
        value="${raw}"
        if [[ "$value" == \"*\" && "$value" == *\" ]]; then
          value="${value#\"}"
          value="${value%\"}"
        elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
          value="${value#\'}"
          value="${value%\'}"
        fi
        lowered="${value:l}"
        if [[ "$lowered" != true && "$lowered" != false ]]; then
          failed=1
          print -u2 -r -- "❌ .private export must be true|false: ${flag}=${raw}"
          print -u2 -r -- "$priv_env_file"
        fi
      fi
    done
  done < "$priv_env_file"

  return "$failed"
}

# main [args...]
# CLI entrypoint for the audit script.
main() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -A opts=()
  zparseopts -D -E -A opts -- -check h -help || return 2

  if (( ${+opts[-h]} || ${+opts[--help]} )); then
    print_usage
    return 0
  fi

  typeset root_dir=''
  root_dir="$(repo_root_from_script)"

  typeset -a files=()
  while IFS= read -r file; do
    [[ -n "$file" ]] && files+=("$file")
  done < <(list_scan_files "$root_dir")

  typeset -i failed=0

  check_no_legacy_names "${files[@]}" || failed=1
  check_no_forbidden_values "${files[@]}" || failed=1

  typeset priv_env_file="$root_dir/.private/priv-env.zsh"
  check_private_exports "$priv_env_file" || failed=1

  if (( failed )); then
    return 1
  fi

  print -u2 -r -- "env-bools audit: OK"
  return 0
}

main "$@"
