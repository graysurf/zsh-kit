# ⏳ Progress Bar Utilities: `progress_bar::*`

This repo ships a small progress bar module for long-running Zsh commands.
It supports:

- **Determinate** progress (`current/total`)
- **Indeterminate** progress (unknown duration)

By default, progress output is **TTY-only** and written to **stderr** to avoid breaking scripts that capture stdout.

---

## 📍 Where It Lives

- Implementation: `scripts/progress-bar.zsh`
- Bootstrap lazy-load shims: `bootstrap/00-preload.zsh`

If you need the functions in a script (or a cached wrapper), source `bootstrap/00-preload.zsh`:

```zsh
source "$ZDOTDIR/bootstrap/00-preload.zsh"
```

---

## 🧩 API

### Determinate

```zsh
progress_bar::init <id> --prefix <text> --total <n> [--width <n>] [--head-len <n>] [--fd <n>] [--enabled|--disabled]
progress_bar::update <id> <current> [--suffix <text>] [--force]
progress_bar::finish <id> [--suffix <text>]
```

### Indeterminate

```zsh
progress_bar::init_indeterminate <id> --prefix <text> [--width <n>] [--head-len <n>] [--fd <n>] [--enabled|--disabled]
progress_bar::tick <id> [--suffix <text>] [--force]
progress_bar::stop <id>
```

Notes:

- `id` should be unique per command invocation (to avoid state collisions).
- `--fd` defaults to `2` (stderr).
- `--enabled` forces output even when the FD is not a TTY (useful for demos/tests).
- Locale controls unicode vs ASCII blocks (e.g. `LC_ALL=C` forces ASCII).

---

## ✅ Examples

### Determinate

```zsh
progress_bar::init pb --prefix "Fetch" --total 10
for i in {1..10}; do
  progress_bar::update pb "$i" --suffix "item=$i"
  sleep 0.05
done
progress_bar::finish pb --suffix "done"
```

### Indeterminate

```zsh
progress_bar::init_indeterminate pb --prefix "Waiting"
while some_condition; do
  progress_bar::tick pb --suffix "fetching..."
  sleep 0.05
done
progress_bar::stop pb
```

---

## 🧠 Integration Pattern (Recommended)

- Gate rendering to interactive terminals (the functions do this by default).
- Always `finish` / `stop` on all exit paths (use `trap` for cleanup).
- Prefer stderr for progress; keep stdout for “real output”.

Example skeleton:

```zsh
emulate -L zsh
setopt pipe_fail err_return nounset

local progress_id="mycmd:${$}"
local progress_active=false

if [[ -t 2 ]] && (( $+functions[progress_bar::init_indeterminate] )); then
  progress_active=true
  progress_bar::init_indeterminate "$progress_id" --prefix "mycmd" --fd 2 || progress_active=false
fi

{
  # ...work...
} always {
  if [[ "$progress_active" == true ]]; then
    progress_bar::stop "$progress_id" || true
  fi
}
```

