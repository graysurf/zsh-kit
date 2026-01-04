# 🌠 codex-starship: Codex Rate Limits for Starship

`codex-starship` prints a single, cacheable status line suitable for a Starship `custom` module.

Default output:

```text
<name> 5h:<pct>% W:<pct>% <weekly_reset_time_utc>
```

Example:

```text
rita 5h:50% W:15% 01-08 10:38
```

If the command cannot determine the active token identity/auth file, it prints nothing and exits `0` (so your prompt does not break).

This command is designed for Starship prompt usage:

- It prints cached output immediately (even if stale).
- It refreshes the cache in the background.
- On a cold cache (first run), it prints nothing and triggers a background refresh.

---

## 🧾 Output Format

- Default:
  - `<name> <window>:<remaining>% W:<remaining>% <weekly_reset_time>`
- With `--no-5h`:
  - `<name> W:<remaining>% <weekly_reset_time>`

Notes:

- `<name>` is resolved by hashing the active auth file and matching it to a known profile under `CODEX_SECRET_DIR`
  (falls back to JWT identity when the secrets directory is unavailable).
- `<weekly_reset_time>` is the UTC reset time from the weekly window (format is configurable via `--time-format`).

---

## 🛠 Usage

```bash
codex-starship --ttl 5m
codex-starship --ttl 1m --no-5h
codex-starship --ttl 5m --time-format '%m-%d %H:%M'
codex-starship --refresh  # force a blocking refresh
```

## 🧩 Wrapper Command

Starship runs external commands, so this repo generates an executable wrapper at:

- `$ZSH_CACHE_DIR/wrappers/bin/codex-starship`

Interactive shells add this wrappers directory to `PATH` automatically.

---

Options:

- `--ttl <duration>`: cache TTL (supports `s`, `m`, `h`, `d`, `w`; default `5m`)
- `--no-5h`: hide the non-weekly window (typically `5h`)
- `--time-format <format>`: weekly reset time format (UTC; default `%m-%d %H:%M`)
- `--refresh`: force a blocking refresh (updates cache; useful for debugging)

---

## 🗃 Cache

The cache is stored under:

- `$ZSH_CACHE_DIR/codex/starship-rate-limits/<token_key>.kv`

Fields:

- `fetched_at=<epoch_seconds>`
- `non_weekly_label=<label>`
- `non_weekly_remaining=<percent>`
- `weekly_remaining=<percent>`
- `weekly_reset_epoch=<epoch_seconds>`

---

## ⭐ Starship Config (example)

This repo already ships a `custom` module configuration in `config/starship.toml`.
If you maintain your own Starship config, add:

```toml
[custom.codex_rate_limits]
symbol = "🌟 "
command = "codex-starship --time-format '%m-%d %H:%M'"
when = "command -v codex-starship >/dev/null 2>&1 && case \"${CODEX_STARSHIP_ENABLED:-}\" in 1|[Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|[Oo][Nn]) : ;; *) exit 1 ;; esac"
format = "[$symbol$output ](bold #637777)"
```

Notes:

- `codex-starship` prints nothing on cold cache/failure; the `[$output ](...)` group avoids printing stray spaces when empty.
- `codex-starship` is disabled by default; set `CODEX_STARSHIP_ENABLED=true` to show this module.

---

## ⚙️ Configuration

- `CODEX_STARSHIP_ENABLED`: enable `codex-starship` output and refresh (default: `false`)
- `CODEX_STARSHIP_TTL`: default cache TTL (default: `5m`)
- `CODEX_STARSHIP_SHOW_5H`: show the non-weekly window (default: `true`; set `false` to hide)
- `CODEX_STARSHIP_REFRESH_MIN_SECONDS`: minimum seconds between background refresh attempts (default: `30`)
- `CODEX_AUTH_FILE`: override the auth file path (default: `~/.config/codex-kit/auth.json`, fallback: `~/.codex/auth.json`)
- `CODEX_SECRET_DIR`: override the secrets/profile directory used for friendly name resolution
- `CODEX_CHATGPT_BASE_URL`: override the API base URL (default: `https://chatgpt.com/backend-api/`)
