# ──────────────────────────────
# Zoxide smart directory jumping
# ──────────────────────────────

if command -v zoxide >/dev/null 2>&1; then
  source <(zoxide init zsh)

  # __zoxide_cd
  # Wrapper to execute `eza -alh` after directory jump.
  # Usage: __zoxide_cd <dir>
  __zoxide_cd() {
    builtin cd -- "$1" || return

    if [[ -o interactive && -t 1 ]]; then
      printf "\n📁 Now in: %s\n\n" "$PWD"
      if command -v eza >/dev/null 2>&1; then
        eza -alh --icons --group-directories-first --time-style=iso || :
      fi
    fi

    return 0
  }
fi

# ──────────────────────────────
# Starship prompt
# ──────────────────────────────

if [[ -f "$ZSH_CONFIG_DIR/starship.toml" ]]; then
  export STARSHIP_CONFIG="$ZSH_CONFIG_DIR/starship.toml"
fi

if [[ -o interactive && -t 0 && -t 1 && -n "${TERM-}" && "${TERM-}" != "dumb" ]] && command -v starship >/dev/null 2>&1; then
  source <(starship init zsh)
fi

# ──────────────────────────────
# Shell behavior options
# ──────────────────────────────

setopt nocaseglob
setopt nocasematch
setopt extendedglob

# ──────────────────────────────
# History substring search key bindings
# ──────────────────────────────

if [[ -o interactive && -t 0 ]]; then
  if (( ${+widgets[history-substring-search-up]} && ${+widgets[history-substring-search-down]} )); then
    if [[ -n "${terminfo[kcuu1]-}" ]]; then
      bindkey "${terminfo[kcuu1]}" history-substring-search-up
    fi
    if [[ -n "${terminfo[kcud1]-}" ]]; then
      bindkey "${terminfo[kcud1]}" history-substring-search-down
    fi
    bindkey -M vicmd 'k' history-substring-search-up
    bindkey -M vicmd 'j' history-substring-search-down
  fi
fi

# ──────────────────────────────
# Cursor shape reset (DECSCUSR)
# ──────────────────────────────
#
# Some full-screen apps (e.g. Vim/Neovim) set the terminal cursor shape and may not restore it
# on exit. Force our preferred cursor shape (steady underline) whenever we return to the prompt.
#
# DECSCUSR (xterm) reference shapes:
# - 0: default, 1/2: block, 3/4: underline, 5/6: bar
if [[ -o interactive && -t 1 && -n "${TERM-}" && "${TERM-}" != "dumb" ]]; then
  zsh_cursor::set_underline() {
    emulate -L zsh
    setopt localoptions nounset

    # DECSCUSR 4: steady underline.
    printf '\033[4 q'
  }

  autoload -Uz add-zsh-hook
  add-zsh-hook -d precmd zsh_cursor::set_underline 2>/dev/null || true
  add-zsh-hook precmd zsh_cursor::set_underline

  # Also apply once at startup (covers shells spawned from apps that changed the cursor).
  zsh_cursor::set_underline
fi
