#!/usr/bin/env -S zsh -f

# install-tools.zsh — Homebrew CLI tool installer
#
# This wrapper script runs the main installer at bootstrap/install-tools.zsh
#
# If you use Homebrew, this helper script installs all required tools declared in:
#   config/tools.list
#
# Usage:
#   ./install-tools.zsh [--dry-run] [--quiet]
#
# Examples:
#   ./install-tools.zsh          # Install missing tools via Homebrew
#   ./install-tools.zsh --dry-run  # Preview what would be installed
#
# Tools will only be installed if not already present on your system.

function _install_tools::ensure_homebrew() {
  emulate -L zsh
  setopt errexit nounset pipefail

  local quiet="$1"

  if command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
    return 0
  fi

  local candidate
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    if [[ -x "$candidate" ]]; then
      eval "$("$candidate" shellenv)"
      return 0
    fi
  done

  if [[ "${OSTYPE:-}" != darwin* ]]; then
    print -u2 -r -- "Homebrew not found; please install it first."
    return 1
  fi

  print -u2 -r -- "Homebrew not found; installing..."

  if [[ "$quiet" == true ]]; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null 2>&1
  else
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  elif command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
  else
    print -u2 -r -- "Homebrew installation finished but brew is still not available."
    return 1
  fi
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

  local repo_root="${0:A:h}"
  local bootstrap_script="$repo_root/bootstrap/install-tools.zsh"

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
