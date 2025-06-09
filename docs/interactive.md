# 🗣️ Shell Runtime Features: `interactive.sh` Overview

This file sets up the runtime behaviors of your Zsh session, including directory navigation, prompt configuration, and key bindings.  
It complements `plugins.sh` by configuring system-level features **after** all plugins are loaded.

---

## 🧭 Directory Navigation Enhancer: Zoxide

```zsh
eval "$(zoxide init zsh)"
```

Overrides the `z` command to provide smart directory jumping **with `eza` preview**.

```zsh
z() {
  if zoxide query -l "$@" &>/dev/null; then
    builtin cd "$(zoxide query "$@")" && {
      echo -e "\n📁 Now in: $PWD\n"
      eza -alh --icons --group-directories-first --time-style=iso
    }
  else
    echo "❌ No matching directory for: $*"
    return 1
  fi
}
```

---

## 💫 Prompt: Starship

If `config/starship.toml` is found, it will be loaded as the custom Starship configuration:

```zsh
export STARSHIP_CONFIG="$ZDOTDIR/config/starship.toml"
eval "$(starship init zsh)"
```

This enables a context-aware, language-sensitive prompt with Git integration, status coloring, and path simplification.

---

## 🔑 Shell Behavior & Keybindings

Zsh options are configured for consistent pattern matching and case-insensitive globbing:

```zsh
setopt nocaseglob nocasematch extended_glob
```

### History Search

Arrow keys (`↑ ↓`) and `j/k` in vi-mode support substring-based history search:

```zsh
bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down
```

---

## 🧠 Summary

These runtime features provide **ergonomic defaults** and **intelligent enhancements** for daily shell workflows.  
They are modular, fast-loading, and work seamlessly with the plugin system — offering a clean, expressive, and productive Zsh experience.

If you wish to extend this runtime layer, consider creating `scripts/runtime.d/*.zsh` and sourcing them in `runtime.sh`.
