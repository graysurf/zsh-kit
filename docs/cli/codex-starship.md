# 🌠 codex-starship: Codex Rate Limits for Starship

`codex-starship` prints a single, cacheable status line suitable for a Starship `custom` module.

Default output:

```text
<name> 5h:<pct>% W:<pct>% <weekly_expire_time_utc>
```

Example:

```text
rita 5h:50% W:15% 2026-01-08T10:38:46Z
```

If the command cannot determine the active token identity, auth file, or rate limits, it prints nothing and exits `0`
(so your prompt does not break).

---

## 🧾 Output Format

- Default:
  - `<name> <window>:<remaining>% W:<remaining>% <weekly_reset_iso>`
- With `--no-5h`:
  - `<name> W:<remaining>% <weekly_reset_iso>`

Notes:

- `<name>` is resolved by hashing the active auth file and matching it to a known profile under `CODEX_SECRET_DIR`
  (falls back to JWT identity when the secrets directory is unavailable).
- `<weekly_reset_iso>` is the UTC reset time from the weekly window.

---

## 🛠 Usage

```bash
codex-starship --ttl 5m
codex-starship --ttl 1m --no-5h
```

## 🧩 Wrapper Command

Starship runs external commands, so this repo generates an executable wrapper at:

- `$ZSH_CACHE_DIR/wrappers/bin/codex-starship`

Interactive shells add this wrappers directory to `PATH` automatically.

---

Options:

- `--ttl <duration>`: cache TTL (supports `s`, `m`, `h`, `d`, `w`; default `5m`)
- `--no-5h`: hide the non-weekly window (typically `5h`)

---

## 🗃 Cache

The cache is stored under:

- `$ZSH_CACHE_DIR/codex/starship-rate-limits/<token_key>.kv`

Fields:

- `fetched_at=<epoch_seconds>`
- `non_weekly_label=<label>`
- `non_weekly_remaining=<percent>`
- `weekly_remaining=<percent>`
- `weekly_reset_iso=<iso_utc>`

---

## ⭐ Starship Config (example)

This repo already ships a `custom` module configuration in `config/starship.toml`.
If you maintain your own Starship config, add:

```toml
[custom.codex_rate_limits]
command = "codex-starship --ttl 5m"
when = "command -v codex-starship >/dev/null 2>&1"
format = "[$output ](bold #637777)"
```

Notes:

- `codex-starship` prints nothing on failure; the `[$output ](...)` group avoids printing stray spaces when empty.

---

## ⚙️ Configuration

- `CODEX_AUTH_FILE`: override the auth file path (default: `~/.config/codex-kit/auth.json`, fallback: `~/.codex/auth.json`)
- `CODEX_SECRET_DIR`: override the secrets/profile directory used for friendly name resolution
- `CODEX_CHATGPT_BASE_URL`: override the API base URL (default: `https://chatgpt.com/backend-api/`)
