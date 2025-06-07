# Reload .zshrc
reload() {
  source "$ZDOTDIR/.zshrc" && echo -e "\n🔁 Reloaded .zshrc"
}

# Open Zsh config in VSCode
edit-zsh() {
  local cwd="$(pwd)"
  code "$ZDOTDIR"
  cd "$cwd" >/dev/null
}

# Use Yazi to navigate, then cd to result
y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(< "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

alias hidpi='bash -c "$(curl -fsSL https://raw.githubusercontent.com/xzhih/one-key-hidpi/master/hidpi.sh)"'

cheat() {
  curl -s cheat.sh/"$@"
}