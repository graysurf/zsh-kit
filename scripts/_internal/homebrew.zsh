# ──────────────────────────────
# Homebrew discovery + env application (shared helper)
# ──────────────────────────────
#
# This module centralizes the brew-candidate list and the
# prefix → `HOMEBREW_*` / `PATH` / `fpath` / `MANPATH` / `INFOPATH`
# application that used to be copy-pasted across `.zprofile`,
# `install-tools.zsh`, and `bootstrap/install-tools.zsh` (where the bootstrap
# copy had drifted to a PATH-only subset).
#
# It exposes:
# - zsh_brew::candidates       — print the standard brew binary candidate paths
# - zsh_brew::discover         — print the first usable brew binary (or return 1)
# - zsh_brew::apply_env <path> — export HOMEBREW_* and wire PATH/fpath/MAN/INFO
#
# Notes:
# - This file is under `_internal/` so it is not auto-loaded; callers opt in via
#   `source`. It only defines functions (no side effects), so re-sourcing is safe.
# - `apply_env` modifies the global `path` / `fpath` and exported vars on
#   purpose; it must not declare those parameters local.

# zsh_brew::candidates
# Print the standard brew binary candidate paths (one per line), whether or not
# they exist. Callers filter for existence as needed.
# Usage: zsh_brew::candidates
zsh_brew::candidates() {
  emulate -L zsh
  setopt nounset

  typeset home="${HOME-}"
  print -r -- /opt/homebrew/bin/brew
  print -r -- /usr/local/bin/brew
  print -r -- /home/linuxbrew/.linuxbrew/bin/brew
  [[ -n "$home" ]] && print -r -- "$home/.linuxbrew/bin/brew"
  return 0
}

# zsh_brew::discover
# Print the path to the first usable `brew` binary on stdout; return 1 if none.
# Usage: zsh_brew::discover
# Notes:
# - Prefers a `brew` already resolvable on PATH (absolute + executable), then
#   falls back to the standard candidate locations.
zsh_brew::discover() {
  emulate -L zsh
  setopt nounset

  typeset brew_path=''
  brew_path="$(command -v brew 2>/dev/null || true)"
  if [[ "$brew_path" == /* && -x "$brew_path" ]]; then
    print -r -- "$brew_path"
    return 0
  fi

  typeset candidate=''
  for candidate in ${(f)"$(zsh_brew::candidates)"}; do
    if [[ -x "$candidate" ]]; then
      print -r -- "$candidate"
      return 0
    fi
  done

  return 1
}

# zsh_brew::apply_env <brew_path>
# Export HOMEBREW_* and ensure brew's bin/sbin/site-functions/man/info are in
# the environment. Existing PATH entries keep their order so a login-shell
# refresh cannot displace an earlier managed command shim; missing entries are
# prepended. Returns 1 for a non-absolute or non-executable path.
# Usage: zsh_brew::apply_env /opt/homebrew/bin/brew
zsh_brew::apply_env() {
  emulate -L zsh
  setopt nounset

  typeset brew_path="${1-}"
  [[ -n "$brew_path" ]] || return 1
  [[ "$brew_path" == /* && -x "$brew_path" ]] || return 1

  typeset homebrew_prefix="${brew_path:h:h}"
  export HOMEBREW_PREFIX="$homebrew_prefix"
  export HOMEBREW_CELLAR="$homebrew_prefix/Cellar"
  export HOMEBREW_REPOSITORY="$homebrew_prefix"

  typeset hb_bin="$homebrew_prefix/bin"
  typeset hb_sbin="$homebrew_prefix/sbin"
  typeset -a missing_paths=()
  [[ -d "$hb_bin" && ${path[(Ie)$hb_bin]} == 0 ]] && missing_paths+=("$hb_bin")
  [[ -d "$hb_sbin" && ${path[(Ie)$hb_sbin]} == 0 ]] && missing_paths+=("$hb_sbin")
  if (( ${#missing_paths[@]} > 0 )); then
    path=("${missing_paths[@]}" "${path[@]}")
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

  return 0
}
