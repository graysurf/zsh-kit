# 🌟 Login Banner: **login.sh**  with Quotes, Emoji

This Zsh environment includes a **login banner system** that injects subtle mood, rotating wisdom,  
and a bit of mechanical sarcasm into each terminal startup — built entirely from local cache and a remote quote API.

---

## ⚙️ What Does It Do?

- 📜 Displays a **random inspirational quote** at login
- 🧠 Shows a **dynamic emoji preamble** with a boot message (because shells deserve ceremony)
- 🌦 (Optional) Prints a cached wttr.in weather snapshot (`bootstrap/weather.sh`, 1-hour TTL) when `ZSH_BOOT_WEATHER=true`
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
5. Calls an emoji script (`random_emoji_cmd.sh`) to inject a random glyph as a boot banner
6. Displays a subtle initialization message before loading the rest of the shell environment:

   ```text
   🌵  Thinking shell initialized. Expect consequences...
   ```

---

## 🧰 Configuration Paths

```zsh
$ZDOTDIR/assets/quotes.txt             # Stored quotes file (text, one per line)
$ZSH_CACHE_DIR/quotes.timestamp        # Last time quote was fetched (unix timestamp)
$ZDOTDIR/tools/random_emoji_cmd.sh     # Emoji selector script (returns one emoji per call)
$ZDOTDIR/bootstrap/weather.sh          # Weather helper (sources wttr.in cache logic)
$ZSH_CACHE_DIR/weather.txt             # Cached wttr.in output
$ZSH_CACHE_DIR/weather.timestamp       # Last time weather was fetched
```

---

## 🌿 Customization Tips

Want to adjust the mood?

- Change the fallback quote to match your tone
- Swap the boot message (`"Thinking shell initialized..."`) to fit your inner monologue
- Edit `random_emoji_cmd.sh` to bias emoji toward certain categories (🛠️, 🌊, 🔮…)

Need a silent login? Wrap `login.sh` in a toggle and only load when `$SHOW_LOGIN_BANNER=true`.

Need weather tweaks? Set `ZSH_WEATHER_URL='https://wttr.in/Taipei?0'` or `ZSH_WEATHER_INTERVAL=900` ahead of sourcing `.zshrc` to change location/refresh cadence.

---

## 🔁 Output Sample

```text
📜 "Be grateful for what you have now, and nothing should be taken for granted." — Roy T. Bennett

🌵  Thinking shell initialized. Expect consequences...

✅ Loaded env.sh in 13ms
✅ Loaded plugins.sh in 41ms
...
```

If `ZSH_BOOT_WEATHER=true`, the login banner is preceded by the cached wttr.in snapshot managed by `bootstrap/weather.sh` (refreshes once per hour; override via `ZSH_WEATHER_INTERVAL=<seconds>`), e.g.:

```text
Weather report: Taipei City, Taiwan

     \  /       Partly cloudy
   _ /"".-.     +25(27) °C
     \_(   ).   ↓ 14 km/h
     /(___(__)  10 km
                0.0 mm
```

---

## 🧠 Summary

This login system is:

- Terminal-native and dependency-light
- Quietly opinionated, but easy to bend
- A small ritual of focus in a world full of noise

Use it, change it, or delete it. But if you're reading quotes in a terminal,  
you're probably doing something right.
