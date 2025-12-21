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

exec "$(dirname "$0")/bootstrap/install-tools.zsh" "$@"
