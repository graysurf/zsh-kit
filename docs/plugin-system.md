# ⚙️ Plugin System: `plugins.sh` Overview

This Zsh environment uses a **manual plugin loader** strategy to keep control over plugin order, reduce startup latency, and avoid plugin manager bloat.

---

## 🧩 Why Manual Plugin Loading?

- ✅ No external plugin managers (like Oh-My-Zsh or Antibody)
- ✅ Precise control over plugin order and configuration
- ✅ Lazy-load capable and script-friendly
- ✅ Unified environment across machines without bootstrap complexity

All plugins are stored under:  
```
$ZDOTDIR/plugins/<plugin-name>/
```

Each plugin is declared in the `ZSH_PLUGINS` array with its main file and optional extras.

---

## 📦 Plugin Declarations

```zsh
ZSH_PLUGINS=(
  "fzf-tab::fzf-tab.plugin.zsh"
  "fast-syntax-highlighting::fast-syntax-highlighting.plugin.zsh"
  "zsh-autosuggestions::zsh-autosuggestions.zsh::ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE=fg=8"
  "zsh-history-substring-search"
  "zsh-direnv"
  "zsh-abbr::zsh-abbr.plugin.zsh::abbr"
)
```

---

## 🔍 Plugin Rationale

### ✅ `fzf-tab`

> Enables `<Tab>` autocompletion with fuzzy-matching and preview, powered by FZF.  
Useful for directories, Git branches, commands, and more.

### ✅ `fast-syntax-highlighting`

> Lightweight and performant syntax highlighter for Zsh.  
Highlights valid/invalid commands, options, and more.

### ✅ `zsh-autosuggestions`

> Real-time autosuggestions in the style of Fish shell.  
Configured to be subtle (`fg=8`) to reduce visual noise.

### ✅ `zsh-history-substring-search`

> Enables history search by typing part of a previous command and using arrow keys to cycle.

### ✅ `zsh-direnv`

> Integrates `.envrc` handling with `direnv` for per-project environment configuration.  
Automatically loads/unloads environment variables based on current directory.

### ✅ `zsh-abbr`

> Command abbreviations with support for expansion, job queue, and completions.  
Needs extra setup (completions, job-queue) and is handled via special case in loader.

---

## 🔄 Plugin Loader Design

Each plugin declaration follows this format:

```
<plugin-name>[::main-file][::extra]
```

Examples:
- `zsh-autosuggestions::zsh-autosuggestions.zsh::ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE=fg=8`
- `zsh-abbr::zsh-abbr.plugin.zsh::abbr` (triggers special-case setup)

The loader:

- Constructs the plugin path
- Sources the plugin file
- Optionally sets environment variables or adds to `fpath` for plugin-specific needs

---

## 🧠 Summary

This plugin loader provides a clean, minimal, and controlled way to configure Zsh behavior and features — without relying on fragile plugin managers.  
It is extensible, shell-native, and compatible across macOS/Linux environments.
