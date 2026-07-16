# ──────────────────────────────
# Define Zsh environment paths (exports only)
# ──────────────────────────────
(( ${+_ZSH_INTERNAL_PATHS_EXPORTS_SOURCED} )) && return 0
typeset -g _ZSH_INTERNAL_PATHS_EXPORTS_SOURCED=1

export ZDOTDIR="${ZDOTDIR:-$HOME/.config/zsh}"

export ZSH_CONFIG_DIR="${ZSH_CONFIG_DIR:-$ZDOTDIR/config}"
export ZSH_BOOTSTRAP_SCRIPT_DIR="${ZSH_BOOTSTRAP_SCRIPT_DIR:-$ZDOTDIR/bootstrap}"
export ZSH_SCRIPT_DIR="${ZSH_SCRIPT_DIR:-$ZDOTDIR/scripts}"
export ZSH_BIN_DIR="${ZSH_BIN_DIR:-$ZDOTDIR/bin}"
export ZSH_TOOLS_DIR="${ZSH_TOOLS_DIR:-$ZDOTDIR/tools}"
export ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$ZDOTDIR/cache}"
export ZSH_COMPDUMP="${ZSH_COMPDUMP:-$ZSH_CACHE_DIR/.zcompdump}"
export HISTFILE="$ZSH_CACHE_DIR/.zsh_history"

# Codex helper defaults. These are non-secret paths/flags; actual token
# material remains in the referenced auth/secret files.
export CODEX_AUTH_FILE="${CODEX_AUTH_FILE:-$HOME/.codex/auth.json}"
export CODEX_SECRET_DIR="${CODEX_SECRET_DIR:-$HOME/.config/codex_secrets}"
export CODEX_PROMPT_SEGMENT_ENABLED="${CODEX_PROMPT_SEGMENT_ENABLED:-false}"
export CLAUDE_PROMPT_SEGMENT_ENABLED="${CLAUDE_PROMPT_SEGMENT_ENABLED:-false}"

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

# Database clients (keg-only Homebrew packages)
[[ -d /opt/homebrew/opt/libpq/bin ]] && _zsh_path_prepend+=(/opt/homebrew/opt/libpq/bin)
[[ -d /usr/local/opt/libpq/bin ]] && _zsh_path_prepend+=(/usr/local/opt/libpq/bin)
[[ -d /home/linuxbrew/.linuxbrew/opt/libpq/bin ]] && _zsh_path_prepend+=(/home/linuxbrew/.linuxbrew/opt/libpq/bin)
[[ -d /opt/homebrew/opt/mysql-client/bin ]] && _zsh_path_prepend+=(/opt/homebrew/opt/mysql-client/bin)
[[ -d /usr/local/opt/mysql-client/bin ]] && _zsh_path_prepend+=(/usr/local/opt/mysql-client/bin)
[[ -d /home/linuxbrew/.linuxbrew/opt/mysql-client/bin ]] && _zsh_path_prepend+=(/home/linuxbrew/.linuxbrew/opt/mysql-client/bin)
[[ -d /opt/homebrew/opt/mssql-tools18/bin ]] && _zsh_path_prepend+=(/opt/homebrew/opt/mssql-tools18/bin)
[[ -d /usr/local/opt/mssql-tools18/bin ]] && _zsh_path_prepend+=(/usr/local/opt/mssql-tools18/bin)
[[ -d /home/linuxbrew/.linuxbrew/opt/mssql-tools18/bin ]] && _zsh_path_prepend+=(/home/linuxbrew/.linuxbrew/opt/mssql-tools18/bin)

# The interactive nils-cli dev override is applied in `.zshrc` before Starship
# initialization. Homebrew login setup preserves established PATH order; keep
# the dev-only override centralized at its interactive consumer boundary.

# Preserve an active fnm multishell ahead of Homebrew so commands keep using
# the same Node/npm prefix that launched the shell.
if [[ -n "${FNM_MULTISHELL_PATH-}" && -d "$FNM_MULTISHELL_PATH/bin" ]]; then
  _zsh_path_prepend+=("$FNM_MULTISHELL_PATH/bin")
fi

# Homebrew
[[ -d /opt/homebrew/bin ]] && _zsh_path_prepend+=(/opt/homebrew/bin /opt/homebrew/sbin)
[[ -d /home/linuxbrew/.linuxbrew/bin ]] && _zsh_path_prepend+=(/home/linuxbrew/.linuxbrew/bin /home/linuxbrew/.linuxbrew/sbin)
[[ -d "$HOME/.linuxbrew/bin" ]] && _zsh_path_prepend+=("$HOME/.linuxbrew/bin" "$HOME/.linuxbrew/sbin")

# Rust (rustup)
[[ -d "$HOME/.cargo/bin" ]] && _zsh_path_prepend+=("$HOME/.cargo/bin")

_zsh_path_prepend+=(
  $ZSH_BIN_DIR
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

# ──────────────────────────────
# FPATH
# ──────────────────────────────
# Keep Homebrew-installed completions visible in non-login interactive shells
# before scripts/interactive/completion.zsh runs compinit. Derive prefixes from
# the resolved PATH order so completion lookup matches command lookup when more
# than one Homebrew prefix exists.
typeset -U fpath=($fpath)
typeset -a _zsh_fpath_prepend=()
typeset _zsh_path_entry='' _zsh_brew_prefix='' _zsh_brew_fpath=''

for _zsh_path_entry in "${path[@]}"; do
  [[ -x "$_zsh_path_entry/brew" ]] || continue
  _zsh_brew_prefix="${_zsh_path_entry:h}"
  _zsh_brew_fpath="$_zsh_brew_prefix/share/zsh/site-functions"
  [[ -d "$_zsh_brew_fpath" ]] || continue
  _zsh_fpath_prepend+=("$_zsh_brew_fpath")
done

if (( ${#_zsh_fpath_prepend[@]} > 0 )); then
  fpath=(
    $_zsh_fpath_prepend
    $fpath
  )
fi

unset _zsh_fpath_prepend _zsh_path_entry _zsh_brew_prefix _zsh_brew_fpath
