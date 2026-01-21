# ──────────────────────────────
# Homebrew environment setup (login shell only)
# ──────────────────────────────

# Notes:
# - `.zprofile` is only loaded for login shells (`zsh -l`).
# - Keep this file silent and minimal (no prompts / no UI / no network).
# - `brew shellenv` configures more than just `PATH` (e.g. `MANPATH`), which is why it lives here.
# - This repo also prepends `/opt/homebrew/bin` (and GNU "gnubin" shims) via
#   `scripts/_internal/paths.exports.zsh` so non-login shells can still find `brew`.
#   See `docs/guides/startup-files.md`.

typeset homebrew_path=''
if command -v brew >/dev/null 2>&1; then
  homebrew_path="$(command -v brew)"
  [[ "$homebrew_path" == /* && -x "$homebrew_path" ]] || homebrew_path=''
fi
if [[ -z "$homebrew_path" ]]; then
  typeset home="${HOME-}"
  typeset -a candidates=(
    /opt/homebrew/bin/brew
    /usr/local/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew
  )
  [[ -n "$home" ]] && candidates+=("$home/.linuxbrew/bin/brew")

  typeset candidate=''
  for candidate in "${candidates[@]}"; do
    [[ -x "$candidate" ]] || continue
    homebrew_path="$candidate"
    break
  done
fi

if [[ -n "$homebrew_path" ]]; then
  typeset homebrew_prefix="${homebrew_path:h:h}"
  export HOMEBREW_PREFIX="$homebrew_prefix"
  export HOMEBREW_CELLAR="$homebrew_prefix/Cellar"
  export HOMEBREW_REPOSITORY="$homebrew_prefix"

  typeset hb_bin="$homebrew_prefix/bin"
  typeset hb_sbin="$homebrew_prefix/sbin"
  typeset -a prefix_paths=() rest_paths=()
  [[ -d "$hb_bin" ]] && prefix_paths+=("$hb_bin")
  [[ -d "$hb_sbin" ]] && prefix_paths+=("$hb_sbin")
  if (( ${#prefix_paths[@]} > 0 )); then
    rest_paths=("${path[@]}")
    rest_paths=("${(@)rest_paths:#$hb_bin}")
    rest_paths=("${(@)rest_paths:#$hb_sbin}")
    path=("${prefix_paths[@]}" "${rest_paths[@]}")
  fi

  typeset hb_fpath="$homebrew_prefix/share/zsh/site-functions"
  if [[ -d "$hb_fpath" ]] && (( ${fpath[(Ie)$hb_fpath]} == 0 )); then
    fpath=("$hb_fpath" $fpath)
  fi

  if [[ -n "${MANPATH-}" ]]; then
    export MANPATH=":${MANPATH#:}"
  fi

  typeset hb_info="$homebrew_prefix/share/info"
  if [[ -d "$hb_info" ]]; then
    export INFOPATH="$hb_info:${INFOPATH-}"
  fi

  export HOMEBREW_AUTO_UPDATE_SECS=604800 # 7 days
fi
