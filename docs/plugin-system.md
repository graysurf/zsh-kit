# 🧩 Plugin System: `plugins.zsh` + `plugin_fetcher.zsh`

This Zsh environment implements a **manual plugin loader system**
with structured declarations and Git-based fetching — offering full control without external plugin managers.

---

## ⚙️ Why Manual Plugin Loading?

- ✅ No external plugin managers (like Oh-My-Zsh, Antibody, Antidote)
- ✅ Exact control over plugin order, configuration, and versioning
- ✅ Git-aware fetcher with dry-run, force, and auto-update support
- ✅ Machine-agnostic and bootstrap-friendly with a clean `plugins.list`

Plugins are stored under:

```zsh
$ZDOTDIR/plugins/<plugin-id>/
```

Each plugin is declared in a standalone file:

```zsh
$ZDOTDIR/config/plugins.list
```

---

## 📦 Plugin Declarations

Each plugin entry in `plugins.list` follows the format:

```zsh
<id>[::main-file][::extra][::git=url]
```

Where:

- `id` is the directory name and plugin key
- `main-file` is the main plugin file (defaults to `<id>.plugin.zsh`)
- `extra` can be:

  - environment variables (e.g. `FOO=bar`)
  - special loader flags (e.g. `abbr`)
- `git=` is the source URL used to clone the plugin if missing

### Example

```zsh
zsh-abbr::zsh-abbr.plugin.zsh::abbr::git=https://github.com/olets/zsh-abbr.git
```

---

## 🔄 Git Fetching & Updates

Plugins are automatically cloned if not present. The fetch logic supports:

- 🔍 Dry-run mode (`PLUGIN_FETCH_DRY_RUN=true`)
- 💥 Forced re-clone (`PLUGIN_FETCH_FORCE=true`)
- 📆 Automatic update every 30 days (tracked in `$ZSH_CACHE_DIR/plugin.timestamp`)

To manually update:

```zsh
plugin_update_all
```

To view status:

```zsh
plugin_print_status
```

---

## 🛠️ Plugin Loader Behavior

Each entry is parsed and loaded via `load_plugin_entry`, which:

- Clones the plugin if missing (via `plugin_fetch_if_missing_from_entry`)
- Loads the main plugin file (or default)
- Applies optional `extra` setup (e.g., env vars, `fpath`, loader hooks)

Special-case logic (e.g., `abbr`) is hardcoded for known plugins needing extra steps.

---

## 📁 File Structure

```text
.zsh/
├── bootstrap/
│   ├── plugins.zsh             # Main loader
│   └── plugin_fetcher.zsh      # Git-aware fetch logic
├── config/
│   ├── plugins.list            # Active plugin declarations
│   └── .plugins.list.example   # Documented example template
```

---

## 🔍 See Also

- [.plugins.list.example](../config/.plugins.list.example) — contains examples and format notes
- [interactive.md](./interactive.md) — runtime behaviors like Starship, Zoxide, keybinds
