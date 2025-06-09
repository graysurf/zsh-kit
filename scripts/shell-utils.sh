# ────────────────────────────────────────────────────────
# Reload the Zsh environment via bootstrap init
# Use for small config changes without restarting shell
# ────────────────────────────────────────────────────────
reload() {
  if source "$ZDOTDIR/bootstrap/init.sh"; then
    echo -e "\n🔁 Reloaded bootstrap/init.sh"
    echo -e "💡 For major changes, consider running: execz"
  else
    echo -e "\n❌ Failed to reload Zsh environment"
  fi
}

# ────────────────────────────────────────────────────────
# Restart shell completely with a fresh session
# Useful after modifying core loader, plugin system, etc.
# ────────────────────────────────────────────────────────
execz() {
  echo -e "\n🚪 Restarting Zsh shell (exec zsh)..."
  echo -e "🧼 This will start a clean session using current configs.\n"
  exec zsh
}

# ────────────────────────────────────────────────────────
# Open your Zsh config directory in VSCode
# ────────────────────────────────────────────────────────
edit-zsh() {
  typeset cwd="$(pwd)"
  code "$ZDOTDIR"
  cd "$cwd" >/dev/null
}

# ────────────────────────────────────────────────────────
# Fuzzy cd using Yazi, then jump to selected directory
# ────────────────────────────────────────────────────────
y() {
  typeset tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(< "$tmp")" && [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# ────────────────────────────────────────────────────────
# Query cheat.sh (curl-based CLI cheatsheets)
# ────────────────────────────────────────────────────────
cheat() {
  curl -s cheat.sh/"$@"
}
