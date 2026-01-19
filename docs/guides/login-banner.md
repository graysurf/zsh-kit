# 🌟 Login Banner: **login.zsh**  with Quotes, Emoji

This Zsh environment includes a **login banner system** that injects subtle mood, rotating wisdom,  
and a bit of mechanical sarcasm into each terminal startup — built entirely from local cache and a remote quote API.

---

## ⚙️ What Does It Do?

- 📜 Displays a **random inspirational quote** at login
- 🧠 Shows a **dynamic emoji preamble** with a boot message (because shells deserve ceremony)
- 🌦 (Optional) Prints a cached wttr.in weather snapshot (`bootstrap/weather.zsh`, 1-hour TTL) when `ZSH_BOOT_WEATHER_ENABLED=true`
- 🌐 Fetches fresh quotes from a public API (`zenquotes.io`) in the background
- 🗂 Stores up to 100 recent quotes locally in a text file for offline fallback
- 🔒 Prevents duplicate execution when sourced multiple times
- ⏱ Avoids excessive API calls with a **1-hour cooldown window**

---

## 🧾 How It Works

On every interactive login, the script:

1. Checks if it has already run (`_LOGIN_SH_EXECUTED`) and exits early if so
2. Picks a random quote from `$ZDOTDIR/assets/quotes.txt` (if the file exists and is not empty)
3. Falls back to a hardcoded default quote if needed
4. In the background:
   - Calls `zenquotes.io/api/random` (max once per hour)
   - Appends the new quote to the local file (max 100 lines)
   - Updates a timestamp file to control frequency
5. Calls an emoji script (`random_emoji_cmd.zsh`) to inject a random glyph as a boot banner
6. Displays a subtle initialization message before loading the rest of the shell environment:

   ```text
   🌵  Thinking shell initialized. Expect consequences...
   ```

---

## 🧰 Configuration Paths

```zsh
$ZDOTDIR/assets/quotes.txt             # Stored quotes file (text, one per line)
$ZSH_CACHE_DIR/quotes.timestamp        # Last time quote was fetched (unix timestamp)
$ZSH_TOOLS_DIR/random_emoji_cmd.zsh    # Emoji selector script (returns one emoji per call)
$ZDOTDIR/bootstrap/weather.zsh          # Weather helper (sources wttr.in cache logic)
$ZSH_CACHE_DIR/weather.txt             # Cached wttr.in output
$ZSH_CACHE_DIR/weather.timestamp       # Last time weather was fetched
```

---

## 🌿 Customization Tips

Want to adjust the mood?

- Change the fallback quote to match your tone
- Swap the boot message (`"Thinking shell initialized..."`) to fit your inner monologue
- Edit `random_emoji_cmd.zsh` to bias emoji toward certain categories (🛠️, 🌊, 🔮…)

Need a silent login? Wrap `login.zsh` in a toggle and only load when `$SHOW_LOGIN_BANNER=true`.

Need weather tweaks? Set `ZSH_WEATHER_URL='https://wttr.in/Taipei?0'` or `ZSH_WEATHER_INTERVAL=900` ahead of sourcing `.zshrc` to change location/refresh cadence.

---

## 🔁 Output Sample

```text
📜 "Be grateful for what you have now, and nothing should be taken for granted." — Roy T. Bennett
🌵  Thinking shell initialized. Expect consequences...
🧩 Features: codex,codex-workspace,docker,opencode
```

If you want per-file timing output during startup, set `ZSH_DEBUG=1` (and higher levels add more detail).

If `ZSH_BOOT_WEATHER_ENABLED=true`, the login banner is preceded by the cached wttr.in snapshot managed by `bootstrap/weather.zsh` (refreshes once per hour; override via `ZSH_WEATHER_INTERVAL=<seconds>`), e.g.:

```text
Weather report: Taipei City, Taiwan

     \  /       Partly cloudy
   _ /"".-.     +25(27) °C
     \_(   ).   ↓ 14 km/h
     /(___(__)  10 km
                0.0 mm
```
