#!/usr/bin/env -S zsh -f

# install-tools.zsh — Homebrew CLI tool installer (macOS/Linux)
#
# This is the user-facing entrypoint for installing tools from config/tools.list.
# It bootstraps Homebrew when missing, then delegates to bootstrap/install-tools.zsh.
#
# This helper script installs all required tools declared in:
#   config/tools.list
# On macOS, it also includes:
#   config/tools.macos.list
# Optional tools can be added from:
#   config/tools.optional.list (with --all)
# On macOS, optional tools can also be added from:
#   config/tools.optional.macos.list (with --all, if present)
#
# Usage:
#   ./install-tools.zsh [--dry-run] [--quiet] [--all]
#
# Examples:
#   ./install-tools.zsh            # Install missing tools via Homebrew
#   ./install-tools.zsh --dry-run  # Preview what would be installed
#   ./install-tools.zsh --all      # Install required + optional
#
# Tools will only be installed if not already present on your system.

typeset -gr SCRIPT_PATH="${0:A}"
typeset -gr REPO_ROOT="${SCRIPT_PATH:h}"
export ZDOTDIR="$REPO_ROOT"

typeset -gr PATHS_FILE="$ZDOTDIR/scripts/_internal/paths.exports.zsh"
if [[ -f "$PATHS_FILE" ]]; then
  source "$PATHS_FILE"
else
  print -u2 -r -- "paths file not found: $PATHS_FILE"
  exit 1
fi

function _install_tools::apply_homebrew_env() {
  emulate -L zsh
  setopt errexit nounset pipefail

  local brew_path="${1-}"
  [[ -n "$brew_path" ]] || return 1
  [[ "$brew_path" == /* && -x "$brew_path" ]] || return 1

  local homebrew_prefix="${brew_path:h:h}"
  export HOMEBREW_PREFIX="$homebrew_prefix"
  export HOMEBREW_CELLAR="$homebrew_prefix/Cellar"
  export HOMEBREW_REPOSITORY="$homebrew_prefix"

  local hb_bin="$homebrew_prefix/bin"
  local hb_sbin="$homebrew_prefix/sbin"
  local -a prefix_paths=() rest_paths=()
  [[ -d "$hb_bin" ]] && prefix_paths+=("$hb_bin")
  [[ -d "$hb_sbin" ]] && prefix_paths+=("$hb_sbin")
  if (( ${#prefix_paths[@]} > 0 )); then
    rest_paths=("${path[@]}")
    rest_paths=("${rest_paths:#$hb_bin}")
    rest_paths=("${rest_paths:#$hb_sbin}")
    path=("${prefix_paths[@]}" "${rest_paths[@]}")
  fi

  local hb_fpath="$homebrew_prefix/share/zsh/site-functions"
  if [[ -d "$hb_fpath" ]] && (( ${fpath[(Ie)$hb_fpath]} == 0 )); then
    fpath=("$hb_fpath" $fpath)
  fi

  if [[ -n "${MANPATH-}" ]]; then
    export MANPATH=":${MANPATH#:}"
  fi

  local hb_info="$homebrew_prefix/share/info"
  if [[ -d "$hb_info" ]]; then
    export INFOPATH="$hb_info:${INFOPATH-}"
  fi

  return 0
}

function _install_tools::ensure_homebrew() {
  emulate -L zsh
  setopt errexit nounset pipefail

  local quiet="$1"

  local home="${HOME-}"
  local -a candidates=(
    /opt/homebrew/bin/brew
    /usr/local/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew
  )
  [[ -n "$home" ]] && candidates+=("$home/.linuxbrew/bin/brew")

  local brew_path=''
  brew_path="$(whence -p brew || true)"
  if [[ -n "$brew_path" ]]; then
    _install_tools::apply_homebrew_env "$brew_path" || return 1
    return 0
  fi

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      _install_tools::apply_homebrew_env "$candidate" || return 1
      return 0
    fi
  done

  case "${OSTYPE-}" in
    darwin*|linux*) ;;
    *)
      print -u2 -r -- "Homebrew not found; unsupported OSTYPE: ${OSTYPE-}"
      return 1
      ;;
  esac

  if ! command -v bash >/dev/null 2>&1; then
    print -u2 -r -- "Homebrew install requires bash."
    return 1
  fi
  if ! command -v curl >/dev/null 2>&1; then
    print -u2 -r -- "Homebrew install requires curl."
    return 1
  fi

  print -u2 -r -- "Homebrew not found; installing..."

  local install_script_url='https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh'
  local install_script=''
  install_script="$(curl -fsSL "$install_script_url")"

  if [[ "$quiet" == true ]]; then
    NONINTERACTIVE=1 bash -c "$install_script" >/dev/null 2>&1
  else
    NONINTERACTIVE=1 bash -c "$install_script"
  fi

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      _install_tools::apply_homebrew_env "$candidate" || return 1
      return 0
    fi
  done

  brew_path="$(whence -p brew || true)"
  if [[ -n "$brew_path" ]]; then
    _install_tools::apply_homebrew_env "$brew_path" || return 1
    return 0
  fi

  print -u2 -r -- "Homebrew installation finished but brew is still not available."
  return 1
}

function _install_tools::brew_update_upgrade() {
  emulate -L zsh
  setopt errexit nounset pipefail

  local quiet="$1"

  if [[ "$quiet" == true ]]; then
    brew update >/dev/null 2>&1
    brew upgrade >/dev/null 2>&1
    return 0
  fi

  brew update
  brew upgrade
}

function _install_tools::ensure_coreutils() {
  emulate -L zsh
  setopt errexit nounset pipefail

  local quiet="$1"

  if brew list --versions coreutils >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$quiet" == true ]]; then
    brew install coreutils >/dev/null 2>&1
    return 0
  fi

  brew install coreutils
}

function _install_tools::main() {
  emulate -L zsh
  setopt errexit nounset pipefail

  local bootstrap_script="$ZSH_BOOTSTRAP_SCRIPT_DIR/install-tools.zsh"
  if [[ ! -x "$bootstrap_script" ]]; then
    print -u2 -r -- "bootstrap script not found or not executable: $bootstrap_script"
    return 1
  fi

  local dry_run=false
  local quiet=false

  local arg
  for arg in "$@"; do
    case "$arg" in
      --dry-run)
        dry_run=true
        ;;
      --quiet)
        quiet=true
        ;;
      --all)
        ;;
    esac
  done

  if [[ "$dry_run" != true ]]; then
    _install_tools::ensure_homebrew "$quiet"
    _install_tools::brew_update_upgrade "$quiet"
    _install_tools::ensure_coreutils "$quiet"
  fi

  exec "$bootstrap_script" "$@"
}

_install_tools::main "$@"
