#!/usr/bin/env -S zsh -f

setopt pipe_fail err_exit nounset

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr REPO_ROOT="${SCRIPT_PATH:h:h}"
export ZDOTDIR="$REPO_ROOT"

typeset -gr PATHS_FILE="$ZDOTDIR/scripts/_internal/paths.exports.zsh"
if [[ -f "$PATHS_FILE" ]]; then
  source "$PATHS_FILE"
else
  print -u2 -r -- "zsh-kit setup: paths file not found: $PATHS_FILE"
  exit 1
fi

typeset -gr PRELOAD_FILE="$ZDOTDIR/bootstrap/00-preload.zsh"
[[ -f "$PRELOAD_FILE" ]] && source "$PRELOAD_FILE"

# zsh_kit_setup::usage
# Print setup-hook usage.
# Usage: zsh_kit_setup::usage
zsh_kit_setup::usage() {
  emulate -L zsh
  setopt pipe_fail nounset

  print -r -- "Usage: bootstrap/zsh-kit-setup.zsh [--features CSV] [--install-tools skip|repo] [--dry-run] [--smoke]"
  print -r -- ""
  print -r -- "Options:"
  print -r -- "  --features CSV          Export CSV as ZSH_FEATURES for setup validation."
  print -r -- "  --install-tools POLICY  skip does nothing; repo runs this repository's installer."
  print -r -- "  --dry-run               Preview repository-owned setup without mutating tools or private state."
  print -r -- "  --smoke                 Run the isolated startup smoke check."
}

# zsh_kit_setup::fail <message> [status]
# Print an error and exit.
# Usage: zsh_kit_setup::fail "message" [status]
zsh_kit_setup::fail() {
  emulate -L zsh
  setopt pipe_fail nounset

  typeset message="$1"
  typeset status="${2:-1}"
  print -u2 -r -- "zsh-kit setup: $message"
  exit "$status"
}

# zsh_kit_setup::is_true <value> [name]
# Return true for strict true|false env flags.
# Usage: zsh_kit_setup::is_true <value> [name]
zsh_kit_setup::is_true() {
  emulate -L zsh
  setopt pipe_fail nounset

  if (( $+functions[zsh_env::is_true] )); then
    zsh_env::is_true "$@"
    return $?
  fi

  typeset value="${1-}"
  [[ "${value:l}" == true ]]
}

# zsh_kit_setup::normalize_features <csv>
# Normalize a comma-separated feature list into $reply.
# Usage: zsh_kit_setup::normalize_features <csv>
zsh_kit_setup::normalize_features() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset csv="${1-}"
  typeset -a normalized=()
  typeset -A seen=()
  typeset -a parts=(${(s:,:)csv})
  typeset part='' token=''

  for part in "${parts[@]}"; do
    token="${part:l}"
    token="${token//[[:space:]]/}"
    [[ -n "$token" ]] || continue

    if [[ ! "$token" =~ '^[a-z0-9_-]+$' ]]; then
      print -u2 -r -- "zsh-kit setup: invalid feature name: $part"
      return 2
    fi
    if [[ -z "${seen[$token]-}" ]]; then
      seen[$token]=1
      normalized+=("$token")
    fi
  done

  reply=("${normalized[@]}")
}

# zsh_kit_setup::validate_bootstrap
# Validate the repo-owned setup entrypoints needed for startup.
# Usage: zsh_kit_setup::validate_bootstrap
zsh_kit_setup::validate_bootstrap() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset -a required=(
    "$REPO_ROOT/.zshenv"
    "$REPO_ROOT/.zshrc"
    "$REPO_ROOT/bootstrap/bootstrap.zsh"
    "$REPO_ROOT/scripts/_internal/paths.exports.zsh"
  )
  typeset file=''
  for file in "${required[@]}"; do
    [[ -r "$file" ]] || {
      print -u2 -r -- "zsh-kit setup: required bootstrap file missing: $file"
      return 1
    }
    zsh -n -- "$file" || return 1
  done
}

# zsh_kit_setup::run_tool_install <policy> <dry_run>
# Apply the forwarded repository tool-install policy.
# Usage: zsh_kit_setup::run_tool_install skip|repo true|false
zsh_kit_setup::run_tool_install() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset policy="$1"
  typeset dry_run="$2"
  typeset installer="$REPO_ROOT/install-tools.zsh"

  case "$policy" in
    skip)
      print -r -- "zsh-kit setup: install-tools skipped"
      ;;
    repo)
      [[ -x "$installer" ]] || {
        print -u2 -r -- "zsh-kit setup: repository installer is not executable: $installer"
        return 1
      }
      if [[ "$dry_run" == true ]]; then
        print -r -- "zsh-kit setup: previewing repository tool installer"
        "$installer" --dry-run --quiet
      else
        print -r -- "zsh-kit setup: running repository tool installer"
        "$installer" --quiet
      fi
      ;;
    *)
      print -u2 -r -- "zsh-kit setup: --install-tools must be skip|repo (got: $policy)"
      return 2
      ;;
  esac
}

# zsh_kit_setup::run_smoke <features_csv>
# Run the repository smoke check in its isolated mode.
# Usage: zsh_kit_setup::run_smoke <features_csv>
zsh_kit_setup::run_smoke() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset features_csv="$1"
  typeset check_script="$REPO_ROOT/tools/check.zsh"
  [[ -x "$check_script" ]] || {
    print -u2 -r -- "zsh-kit setup: smoke check script is not executable: $check_script"
    return 1
  }

  print -r -- "zsh-kit setup: running smoke validation"
  ZSH_FEATURES="$features_csv" "$check_script" --smoke
}

# zsh_kit_setup::main [args...]
# Hook entrypoint consumed by nils-cli zsh-kit setup.
# Usage: zsh_kit_setup::main "$@"
zsh_kit_setup::main() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset features_csv=''
  typeset install_tools='skip'
  typeset dry_run=false
  typeset smoke=false

  if zsh_kit_setup::is_true "${ZSH_KIT_SETUP_DRY_RUN_ENABLED-}" "ZSH_KIT_SETUP_DRY_RUN_ENABLED"; then
    dry_run=true
  fi
  if zsh_kit_setup::is_true "${ZSH_KIT_SETUP_SMOKE_ENABLED-}" "ZSH_KIT_SETUP_SMOKE_ENABLED"; then
    smoke=true
  fi

  while (( $# > 0 )); do
    case "$1" in
      --features)
        shift || zsh_kit_setup::fail "--features requires a value" 2
        (( $# > 0 )) || zsh_kit_setup::fail "--features requires a value" 2
        features_csv="$1"
        ;;
      --features=*)
        features_csv="${1#--features=}"
        ;;
      --install-tools)
        shift || zsh_kit_setup::fail "--install-tools requires a value" 2
        (( $# > 0 )) || zsh_kit_setup::fail "--install-tools requires a value" 2
        install_tools="$1"
        ;;
      --install-tools=*)
        install_tools="${1#--install-tools=}"
        ;;
      --dry-run)
        dry_run=true
        ;;
      --smoke)
        smoke=true
        ;;
      -h|--help)
        zsh_kit_setup::usage
        return 0
        ;;
      *)
        zsh_kit_setup::fail "unknown option: $1" 2
        ;;
    esac
    shift || true
  done

  zsh_kit_setup::normalize_features "$features_csv" || return $?
  typeset -a normalized_features=("${reply[@]}")
  features_csv="${(j:,:)normalized_features}"
  export ZSH_FEATURES="$features_csv"

  zsh_kit_setup::validate_bootstrap || return $?

  print -r -- "zsh-kit setup: repository=$REPO_ROOT"
  if [[ -n "$features_csv" ]]; then
    print -r -- "zsh-kit setup: features=$features_csv"
  else
    print -r -- "zsh-kit setup: features=(none)"
  fi
  typeset mode='apply'
  [[ "$dry_run" == true ]] && mode='dry-run'
  print -r -- "zsh-kit setup: mode=$mode"

  zsh_kit_setup::run_tool_install "$install_tools" "$dry_run" || return $?
  if [[ "$smoke" == true ]]; then
    zsh_kit_setup::run_smoke "$features_csv" || return $?
  fi

  print -r -- "zsh-kit setup: complete"
}

zsh_kit_setup::main "$@"
