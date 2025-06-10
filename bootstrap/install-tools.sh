#!/bin/bash

# install-tools.sh — Install required CLI tools via Homebrew (macOS only)
#
# Usage:
#   ./install-tools.sh [--dry-run] [--quiet]
#
# Options:
#   --dry-run   Simulate the installation process without installing anything.
#               Useful for previewing which tools are missing.
#
#   --quiet     Suppress all Homebrew output during installation.
#               Only summary messages will be shown.
#
# Description:
#   This script checks for required CLI tools defined in ./config/tools.list.
#   It prompts for confirmation before proceeding, unless --dry-run is used.
#
#   If all tools are already installed, it exits cleanly with a success message.
#
# Example:
#   DRY_RUN=true ./install-tools.sh      # Alternate dry-run using env var
#   ./install-tools.sh --quiet           # Quiet mode install

TOOLS_LIST="./config/tools.list"
DRY_RUN=false
QUIET=false

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=true
      ;;
    --quiet)
      QUIET=true
      ;;
    *)
      printf "❌ Unknown option: %s\\n" "$arg"
      printf "Usage: %s [--dry-run] [--quiet]\\n" "$0"
      exit 1
      ;;
  esac
done

if [ ! -f "$TOOLS_LIST" ]; then
  printf "❌ tools.list not found at %s\\n" "$TOOLS_LIST"
  exit 1
fi

if [ "$DRY_RUN" = true ]; then
  printf "🧪 DRY RUN mode enabled — no installations will be performed\\n"
fi

if [ "$QUIET" = true ]; then
  printf "🔇 QUIET mode enabled — suppressing brew output\\n"
fi

# Scan for missing tools (only if not dry-run)
if [ "$DRY_RUN" != true ]; then
  missing=()
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    IFS="::" read -r tool brew_name comment <<< "$line"
    brew_name="${brew_name:-$tool}"
    if ! command -v "$tool" >/dev/null 2>&1; then
      missing+=("$tool")
    fi
  done < "$TOOLS_LIST"

  if (( ${#missing[@]} > 0 )); then
    printf "📦 The following tools are missing and will be installed via Homebrew:\\n"
    for tool in "${missing[@]}"; do
      printf "  - %s\\n" "$tool"
    done
    printf "\\n"
    printf "🛠  You can run this script with --dry-run to preview without installing.\\n"
    printf "❓ Proceed with installation? [y/N]: "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      printf "❌ Aborted by user.\\n"
      exit 1
    fi
  else
    printf "✅ All tools are already installed. Nothing to do.\\n"
    exit 0
  fi
fi

printf "🔍 Checking and installing CLI tools via Homebrew...\\n"

# Counters
installed=0
skipped=0
failed=0

while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

  IFS="::" read -r tool brew_name comment <<< "$line"
  brew_name="${brew_name:-$tool}"

  printf "🔧 %-12s " "$tool"

  if command -v "$tool" >/dev/null 2>&1; then
    printf "✓ Already installed\\n"
    ((skipped++))
    continue
  fi

  if [ "$DRY_RUN" = true ]; then
    printf "💤 Skipped due to dry-run (%s)\\n" "$brew_name"
    continue
  else
    printf "➕ Will install (%s)...\\n" "$brew_name"
  fi

  if [ "$QUIET" = true ]; then
    if brew install "$brew_name" >/dev/null 2>&1; then
      printf "✅ %s installed\\n" "$tool"
      ((installed++))
    else
      printf "❌ Failed to install %s\\n" "$tool"
      ((failed++))
    fi
  else
    if brew install "$brew_name"; then
      printf "✅ %s installed\\n" "$tool"
      ((installed++))
    else
      printf "❌ Failed to install %s\\n" "$tool"
      ((failed++))
    fi
  fi
done < "$TOOLS_LIST"

printf "\\n"
printf "🧾 Install Summary:\\n"
printf "   ✅ Installed: %d\\n" "$installed"
printf "   ⏭ Skipped:   %d\\n" "$skipped"
printf "   ❌ Failed:    %d\\n" "$failed"
