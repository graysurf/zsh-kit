# ──────────────────────────────
# Homebrew environment setup (login shell only)
# ──────────────────────────────

# Notes:
# - `.zprofile` is only loaded for login shells (`zsh -l`).
# - Keep this file silent and minimal (no prompts / no UI / no network).
# - `brew shellenv` configures more than just `PATH` (e.g. `MANPATH`), which is why it lives here.
# - This repo also prepends `/opt/homebrew/bin` (and GNU "gnubin" shims) via
#   `scripts/_internal/paths.exports.zsh` so non-login shells can still find `brew`.
#   See `docs/startup-files.md`.

typeset homebrew_path=''
if command -v brew >/dev/null 2>&1; then
  homebrew_path="$(command -v brew)"
else
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
  eval "$("$homebrew_path" shellenv)"
  export HOMEBREW_AUTO_UPDATE_SECS=604800 # 7 days
fi
