# 🌠 codex-starship: Codex Rate Limits for Starship

`codex-starship` prints a single, cacheable status line suitable for a Starship `custom` module.

This command is shipped as an optional feature. Enable it by including `codex` in `ZSH_FEATURES` (e.g. in your home `~/.zshenv`).

Default output:

```text
[<name> ]5h:<pct>% W:<pct>% <weekly_reset_time_utc>
```

Example:

```text
yourname 5h:50% W:15% 01-08 10:38
```

If the command cannot determine the active token identity/auth file, it prints nothing and exits `0` (so your prompt does not break).

This command is designed for Starship prompt usage:

- It prints cached output immediately (even if stale).
- It refreshes the cache in the background.
- On a cold cache (first run), it prints nothing and triggers a background refresh.

---

## 🧾 Output Format

- Default:
  - `[<name> ]<window>:<remaining>% W:<remaining>% <weekly_reset_time>`
- With `--no-5h`:
  - `[<name> ]W:<remaining>% <weekly_reset_time>`
- When cache is stale:
  - `... (stale)` (suffix; configurable)

Notes:

- `<name>` defaults to the matched profile filename under `CODEX_SECRET_DIR`:
  - Prefer: JWT identity + `account_id` (stable across token refreshes).
  - Fallback: SHA-256 whole-file hash (requires the profile file to be byte-identical).
  - If a friendly profile match is not found, the name is omitted by default; set `CODEX_STARSHIP_SHOW_FALLBACK_NAME_ENABLED=true`
    to show a fallback name (prefer JWT `.email` local-part when available; otherwise JWT-derived identity like `user-...`).
- Set `CODEX_STARSHIP_NAME_SOURCE=email` to show the JWT email instead of the secrets/profile filename.
  - Default: show only the local-part (before `@`); set `CODEX_STARSHIP_SHOW_FULL_EMAIL_ENABLED=true` to show the full email.
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
- `$ZSH_CACHE_DIR/codex/starship-rate-limits/<token_key>.refresh.at` (last refresh attempt epoch seconds)

Fields:

- `fetched_at=<epoch_seconds>`
- `non_weekly_label=<label>`
- `non_weekly_remaining=<percent>`
- `weekly_remaining=<percent>`
- `weekly_reset_epoch=<epoch_seconds>`

Other refresh artifacts (auto-cleaned when stale):

- `$ZSH_CACHE_DIR/codex/starship-rate-limits/<token_key>.refresh.lock` (lock dir)
- `$ZSH_CACHE_DIR/codex/starship-rate-limits/wham.usage.*` (temp files)

Notes:

- When a friendly profile match is not found, `<token_key>` falls back to `auth_<sha256>` (derived from the auth file contents),
  which can change across auth refreshes.
- To avoid unbounded growth of `auth_<sha256>` cache entries, `codex-starship` keeps a bounded number (see `CODEX_STARSHIP_AUTH_HASH_CACHE_KEEP`).

---

## ⭐ Starship Config (example)

This repo already ships a `custom` module configuration in `config/starship.toml`.
If you maintain your own Starship config, add:

```toml
[custom.codex_rate_limits]
symbol = "🌟 "
command = "codex-starship --time-format '%m-%d %H:%M'"
when = "command -v codex-starship >/dev/null 2>&1 && codex-starship --is-enabled"
format = "[$symbol$output ](bold #637777)"
```

Notes:

- `codex-starship` prints nothing on cold cache/failure; the `[$output ](...)` group avoids printing stray spaces when empty.
- `codex-starship` is disabled by default; enable feature `codex` (`ZSH_FEATURES=codex`) and set `CODEX_STARSHIP_ENABLED=true` to show this module.

---

## ⚙️ Configuration

| Env | Default | Options | Description |
| --- | --- | --- | --- |
| `CODEX_STARSHIP_ENABLED` | `false` | `true|false` | Enable `codex-starship` output + refresh. |
| `CODEX_STARSHIP_TTL` | `5m` | `seconds` or `Ns|Nm|Nh|Nd|Nw` | Cache TTL. |
| `CODEX_STARSHIP_SHOW_5H_ENABLED` | `true` | `true|false` | Show the non-weekly window (typically `5h`). |
| `CODEX_STARSHIP_SHOW_FALLBACK_NAME_ENABLED` | `false` | `true|false` | When no profile match, show a fallback name (email local-part when available; otherwise JWT identity). |
| `CODEX_STARSHIP_NAME_SOURCE` | `secret` | `secret|email` | Name source (`secret` = profile filename; `email` = JWT email). |
| `CODEX_STARSHIP_SHOW_FULL_EMAIL_ENABLED` | `false` | `true|false` | When using email names, show full email (otherwise local-part only). |
| `CODEX_STARSHIP_REFRESH_MIN_SECONDS` | `30` | integer seconds | Minimum seconds between background refresh attempts. |
| `CODEX_STARSHIP_STALE_SUFFIX` | ` (stale)` | string (empty disables) | Suffix appended when cached output is stale. |
| `CODEX_STARSHIP_LOCK_STALE_SECONDS` | `90` | integer seconds | Consider refresh artifacts stale after N seconds and clear them. |
| `CODEX_STARSHIP_AUTH_HASH_CACHE_KEEP` | `5` | integer (`0` disables) | Max number of `auth_<sha256>` cache entries to keep. |
| `CODEX_STARSHIP_CURL_CONNECT_TIMEOUT_SECONDS` | `2` | integer seconds | `curl` connect timeout for `wham/usage` fetch. |
| `CODEX_STARSHIP_CURL_MAX_TIME_SECONDS` | `8` | integer seconds | `curl` max time for `wham/usage` fetch. |
| `CODEX_AUTH_FILE` | `~/.codex/auth.json` | file path | Override the active auth file path. |
| `CODEX_SECRET_DIR` | `$ZDOTDIR/scripts/_features/codex/secrets` | directory path | Secrets/profile dir used for friendly name resolution. |
| `CODEX_CHATGPT_BASE_URL` | `https://chatgpt.com/backend-api/` | URL | Override the API base URL. |
