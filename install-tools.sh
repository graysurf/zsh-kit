#!/bin/bash

# install-tools.sh — Homebrew CLI tool installer
#
# This wrapper script runs the main installer at bootstrap/install-tools.sh
#
# If you use Homebrew, this helper script installs all required tools declared in:
#   config/tools.list
#
# Usage:
#   ./install-tools.sh [--dry-run] [--quiet]
#
# Examples:
#   ./install-tools.sh          # Install missing tools via Homebrew
#   ./install-tools.sh --dry-run  # Preview what would be installed
#
# Tools will only be installed if not already present on your system.

exec "$(dirname "$0")/bootstrap/install-tools.sh" "$@"
