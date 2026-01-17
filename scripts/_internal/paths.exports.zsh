# ──────────────────────────────
# Define Zsh environment paths (exports only)
# ──────────────────────────────
(( ${+_ZSH_INTERNAL_PATHS_EXPORTS_SOURCED} )) && return 0
typeset -g _ZSH_INTERNAL_PATHS_EXPORTS_SOURCED=1

export ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"

export ZSH_CONFIG_DIR="${ZSH_CONFIG_DIR:-$ZDOTDIR/config}"
export ZSH_BOOTSTRAP_SCRIPT_DIR="${ZSH_BOOTSTRAP_SCRIPT_DIR:-$ZDOTDIR/bootstrap}"
export ZSH_SCRIPT_DIR="${ZSH_SCRIPT_DIR:-$ZDOTDIR/scripts}"
export ZSH_TOOLS_DIR="${ZSH_TOOLS_DIR:-$ZDOTDIR/tools}"
export ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$ZDOTDIR/cache}"
export ZSH_COMPDUMP="${ZSH_COMPDUMP:-$ZSH_CACHE_DIR/.zcompdump}"
export HISTFILE="$ZSH_CACHE_DIR/.zsh_history"

# ──────────────────────────────
# PATH
# ──────────────────────────────
# Use unique path entries (prevents duplicates)
typeset -U path=($path) PATH="${PATH-}"

# Prepend critical paths to PATH
typeset -a _zsh_path_prepend=()

# GNU tools (Homebrew "gnubin" shims)
[[ -d /opt/homebrew/opt/coreutils/libexec/gnubin ]] && _zsh_path_prepend+=(/opt/homebrew/opt/coreutils/libexec/gnubin)
[[ -d /opt/homebrew/opt/grep/libexec/gnubin ]] && _zsh_path_prepend+=(/opt/homebrew/opt/grep/libexec/gnubin)
[[ -d /usr/local/opt/coreutils/libexec/gnubin ]] && _zsh_path_prepend+=(/usr/local/opt/coreutils/libexec/gnubin)
[[ -d /usr/local/opt/grep/libexec/gnubin ]] && _zsh_path_prepend+=(/usr/local/opt/grep/libexec/gnubin)

# Homebrew (Apple Silicon)
[[ -d /opt/homebrew/bin ]] && _zsh_path_prepend+=(/opt/homebrew/bin /opt/homebrew/sbin)

_zsh_path_prepend+=(
  /usr/local/bin
  /usr/bin
  $HOME/bin
  $HOME/.local/bin
)

path=(
  $_zsh_path_prepend
  $path
)

unset _zsh_path_prepend
