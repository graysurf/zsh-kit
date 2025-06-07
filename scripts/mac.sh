# ────────────────────────────────────────────────────────
# Locale settings (prevent encoding issues)
# ────────────────────────────────────────────────────────

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# ────────────────────────────────────────────────────────
# PATH setup for macOS tools (Homebrew + VSCode CLI)
# ────────────────────────────────────────────────────────

export PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"
export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"

# ────────────────────────────────────────────────────────
# macOS-specific convenience aliases
# ────────────────────────────────────────────────────────

alias f='open'  # Quick open file or dir with default macOS app