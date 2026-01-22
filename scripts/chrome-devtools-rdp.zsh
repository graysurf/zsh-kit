# Remote debugging ports for the browser RDP helpers.
typeset -x CHROME_REMOTE_DEBUG_PORT_DEFAULT="${CHROME_REMOTE_DEBUG_PORT_DEFAULT:-19222}"

typeset -x CHROME_REMOTE_DEBUG_PROFILE_DIR_DEFAULT="${CHROME_REMOTE_DEBUG_PROFILE_DIR_DEFAULT:-${HOME}/.codex/chrome-profile}"
typeset -x CHROME_DEFAULT_PROFILE_DIR="${CHROME_DEFAULT_PROFILE_DIR:-${HOME}/Library/Application Support/Google/Chrome}"
typeset -x CHROME_DEFAULT_LOCAL_STATE="${CHROME_DEFAULT_LOCAL_STATE:-${CHROME_DEFAULT_PROFILE_DIR}/Local State}"

# Cache base for devtools profiles
typeset -x CHROME_DEVTOOLS_CACHE_BASE="${CHROME_DEVTOOLS_CACHE_BASE:-${ZSH_CACHE_DIR:-${HOME}/.cache/zsh}/chrome-devtools}"
typeset -x CHROME_PROFILE_CACHE_DIR="${CHROME_PROFILE_CACHE_DIR:-${CHROME_DEVTOOLS_CACHE_BASE}/profiles/chrome}"
typeset -x CHROME_PROFILE_CACHE_DEFAULT_DIR="${CHROME_PROFILE_CACHE_DEFAULT_DIR-}"

if [[ "${CHROME_PROFILE_CACHE_DIR:t}" == "Default" ]]; then
  typeset -x CHROME_PROFILE_CACHE_DEFAULT_DIR="${CHROME_PROFILE_CACHE_DIR}"
  typeset -x CHROME_PROFILE_CACHE_DIR="${CHROME_PROFILE_CACHE_DIR:h}"
elif [[ -z "${CHROME_PROFILE_CACHE_DEFAULT_DIR-}" ]]; then
  typeset -x CHROME_PROFILE_CACHE_DEFAULT_DIR="${CHROME_PROFILE_CACHE_DIR}/Default"
fi

# Optional explicit user-data-dir overrides (blank means use existing default profile)
typeset -x CHROME_REMOTE_DEBUG_USER_DATA_DIR_DEFAULT="${CHROME_REMOTE_DEBUG_USER_DATA_DIR_DEFAULT-}"

# ---- shared helpers ---------------------------------------------------------

# _confirm_or_abort <question>
# Prompt for confirmation; return non-zero if declined or non-interactive.
# Usage: _confirm_or_abort <question>
# Env:
# - RDP_ASSUME_YES_ENABLED: when true, auto-confirm without prompting.
_confirm_or_abort() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset question="${1-}"

  if zsh_env::is_true "${RDP_ASSUME_YES_ENABLED-}" "RDP_ASSUME_YES_ENABLED"; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    print -u2 -r -- "🚫 Aborted (non-interactive): $question"
    print -u2 -r -- "   Tip: set RDP_ASSUME_YES_ENABLED=true to auto-confirm."
    return 1
  fi

  print -n -r -- "❓ ${question} [y/N] "
  typeset confirm=''
  IFS= read -r confirm
  if [[ "$confirm" != [yY] ]]; then
    print -r -- "🚫 Aborted"
    return 1
  fi
  return 0
}

# _port_in_use <port>
# Print listener info for a TCP port (best-effort).
# Usage: _port_in_use <port>
# Notes:
# - macOS: relies on `lsof`.
_port_in_use() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset port="${1-}"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null
}

# _rdp_endpoint_ready <port>
# Return success if the Chrome DevTools HTTP endpoint is responding on the port.
# Usage: _rdp_endpoint_ready <port>
# Notes:
# - Requires `curl`.
_rdp_endpoint_ready() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset port="${1-}"
  (( port > 0 )) || return 1

  command -v curl >/dev/null 2>&1 || return 1

  typeset url="http://127.0.0.1:${port}/json/version"
  typeset body=''
  body="$(curl -fsS -m 1 -- "$url" 2>/dev/null || true)" || return 1
  [[ "$body" == *webSocketDebuggerUrl* ]] || return 1
  return 0
}

# _quit_app_gracefully <app_name>
# Ask a macOS app to quit via AppleScript and wait briefly for exit.
# Usage: _quit_app_gracefully <app_name>
_quit_app_gracefully() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset app_name="${1-}"

  # Ask the app to quit
  osascript -e "tell application \"$app_name\" to quit" >/dev/null 2>&1 || true

  # Wait a bit for it to exit (short + deterministic)
  typeset -i i=0
  for i in {1..20}; do
    sleep 0.1
    if ! pgrep -x "$app_name" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

# _force_kill_by_path <exe_path>
# Force-kill processes whose command line matches the given executable path.
# Usage: _force_kill_by_path <exe_path>
# Safety:
# - Uses `kill -9` (best-effort).
_force_kill_by_path() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset exe_path="${1-}"
  # Match the full path in command line; kill -9 to ensure it's gone
  typeset -a pids=()
  pids=("${(@f)$(pgrep -f -- "$exe_path" 2>/dev/null)}")
  if (( ${#pids[@]} > 0 )); then
    kill -9 -- "${pids[@]}" >/dev/null 2>&1 || true
  fi
}

# _browser_running <app_name> <exe_path>
# Return success if the browser appears to be running (by process name or exe path).
# Usage: _browser_running <app_name> <exe_path>
_browser_running() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset app_name="${1-}"
  typeset exe_path="${2-}"

  # pgrep -x checks exact process name (works for "Google Chrome" often)
  if pgrep -x "$app_name" >/dev/null 2>&1; then
    return 0
  fi

  # Fallback: match exe path in command line
  if pgrep -f -- "$exe_path" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

# _kill_all_chrome_processes <app_name> <exe_path>
# Terminate browser processes (best-effort) for relaunch.
# Usage: _kill_all_chrome_processes <app_name> <exe_path>
# Safety:
# - Sends SIGTERM then SIGKILL to matched PIDs.
_kill_all_chrome_processes() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset app_name="${1-}"
  typeset exe_path="${2-}"

  typeset -a pids=()
  pids=(
    "${(@f)$(pgrep -f -- "$exe_path" 2>/dev/null || true)}"
    "${(@f)$(pgrep -f -- "${app_name} Helper" 2>/dev/null || true)}"
  )
  if (( ${#pids[@]} == 0 )); then
    return 0
  fi

  pids=(${(u)pids})
  kill -- "${pids[@]}" >/dev/null 2>&1 || true
  sleep 0.3
  kill -9 -- "${pids[@]}" >/dev/null 2>&1 || true
  return 0
}

# _wait_for_browser_exit <app_name> <exe_path>
# Wait for browser processes to exit (short bounded wait).
# Usage: _wait_for_browser_exit <app_name> <exe_path>
_wait_for_browser_exit() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset app_name="${1-}"
  typeset exe_path="${2-}"

  typeset -i i=0
  for i in {1..50}; do
    if ! _browser_running "$app_name" "$exe_path"; then
      if ! pgrep -f -- "${app_name} Helper" >/dev/null 2>&1; then
        return 0
      fi
    fi
    sleep 0.1
  done
  return 1
}

# _cleanup_singleton_locks <profile_dir>
# Remove stale Chrome Singleton* lock/socket files under a profile directory.
# Usage: _cleanup_singleton_locks <profile_dir>
# Safety:
# - Deletes files named `SingletonLock`, `SingletonCookie`, `SingletonSocket`.
_cleanup_singleton_locks() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset profile_dir="${1-}"
  [[ -d "$profile_dir" ]] || return 0

  # Remove stale single-instance lock/socket files that can make Chrome bounce.
  typeset -a lock_files=(
    "$profile_dir/SingletonLock"
    "$profile_dir/SingletonCookie"
    "$profile_dir/SingletonSocket"
  )

  typeset path=''
  for path in "${lock_files[@]}"; do
    if [[ -e "$path" ]]; then
      command rm -f -- "$path" >/dev/null 2>&1 || true
    fi
  done
}

# _ensure_cached_default_profile <app_name> <source_dir> <target_dir> [local_state_path]
# Create/refresh a cached copy of a browser profile for remote debugging.
# Usage: _ensure_cached_default_profile <app_name> <source_dir> <target_dir> [local_state_path]
# Env:
# - RDP_REFRESH_PROFILE_ENABLED: when true, force refresh of the cached profile.
# Notes:
# - Uses `rsync` when available; falls back to `cp`.
_ensure_cached_default_profile() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset app_name="${1-}"
  typeset source_dir="${2-}"
  typeset target_dir="${3-}"
  typeset local_state_path="${4-}"
  typeset target_root="${target_dir:h}"

  if [[ -z "$app_name" || -z "$source_dir" || -z "$target_dir" ]]; then
    print -u2 -r -- "❌ Missing parameters for caching default profile."
    return 1
  fi

  if [[ ! -d "$source_dir" ]]; then
    print -u2 -r -- "❌ Default profile not found for $app_name: $source_dir"
    return 1
  fi

  if ! command mkdir -p -- "$target_dir" >/dev/null 2>&1; then
    print -u2 -r -- "❌ Cannot create cache dir: $target_dir"
    return 1
  fi

  typeset -i refresh=0
  if zsh_env::is_true "${RDP_REFRESH_PROFILE_ENABLED-}" "RDP_REFRESH_PROFILE_ENABLED"; then
    refresh=1
  fi

  if [[ ! -f "$target_dir/Preferences" || ! -f "$target_root/Local State" ]]; then
    if (( refresh == 0 )); then
      print -r -- "🔄 Cache incomplete; refreshing default $app_name profile."
    fi
    refresh=1
  fi

  if (( refresh == 1 )) || [[ ! -d "$target_dir" ]]; then
    print -r -- "📁 Caching default $app_name profile → $target_dir"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete \
        --exclude 'Singleton*' \
        --exclude 'Crashpad' \
        --exclude 'GoogleUpdater*' \
        --exclude 'GrShaderCache' \
        --exclude 'GPUCache' \
        --exclude 'ShaderCache' \
        --exclude 'Code Cache' \
        --exclude 'Service Worker' \
        --exclude 'BrowserMetrics*' \
        -- "$source_dir"/ "$target_dir"/
    else
      command rm -rf -- "$target_dir" >/dev/null 2>&1 || true
      command mkdir -p -- "$target_dir" >/dev/null 2>&1 || true
      command cp -R "$source_dir"/. "$target_dir"/ >/dev/null 2>&1 || {
        print -u2 -r -- "❌ Failed to copy profile (rsync not available)."
        return 1
      }
      # Prune heavy/transient dirs when falling back to cp
      setopt null_glob
      typeset -a prune_dirs=(
        "$target_dir"/Singleton*
        "$target_dir"/Crashpad
        "$target_dir"/GrShaderCache
        "$target_dir"/GPUCache
        "$target_dir"/ShaderCache
        "$target_dir"/"Code Cache"
        "$target_dir"/"Service Worker"
        "$target_dir"/BrowserMetrics*
      )
      command rm -rf -- "${prune_dirs[@]}" 2>/dev/null || true
    fi
  fi

  # Copy Local State alongside the profile (best-effort)
  if [[ -n "$local_state_path" && -f "$local_state_path" ]]; then
    typeset dest_local_state="${target_root}/Local State"
    if (( refresh == 1 )) || [[ ! -f "$dest_local_state" ]]; then
      print -r -- "📄 Syncing Local State → $dest_local_state"
      if command -v rsync >/dev/null 2>&1; then
        rsync -a -- "$local_state_path" "$dest_local_state"
      else
        command cp -f -- "$local_state_path" "$dest_local_state" >/dev/null 2>&1 || true
      fi
    fi
  fi

  typeset target_root="${target_dir:h}"
  _cleanup_singleton_locks "$target_root"
  print -r -- "✅ Cached profile ready at: $target_root"
  return 0
}

# ---- main launcher ----------------------------------------------------------

# _launch_rdp <app_name> <exe_path> <port> [user_data_dir]
# Launch a Chromium-based browser with a DevTools remote debugging endpoint.
# Usage: _launch_rdp <app_name> <exe_path> <port> [user_data_dir]
# Env:
# - RDP_ASSUME_YES_ENABLED: when true, auto-confirm prompts.
# - RDP_DEBUG_ENABLED: when true, write debug log.
# - RDP_DEBUG_LOG: debug log path (default: ~/.codex/chrome-rdp.log).
# Safety:
# - May terminate browser processes and remove stale profile lock files.
_launch_rdp() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  typeset app_name="${1-}"
  typeset exe_path="${2-}"
  typeset -i port="${3-0}"
  typeset user_data_dir="${4-}"

  typeset -i rdp_debug=0
  if zsh_env::is_true "${RDP_DEBUG_ENABLED-}" "RDP_DEBUG_ENABLED"; then
    rdp_debug=1
  fi
  typeset rdp_debug_log="${RDP_DEBUG_LOG:-${HOME}/.codex/chrome-rdp.log}"

  [[ -x "$exe_path" ]] || { print -r -- "❌ Executable not found: $exe_path"; return 1; }

  # If the endpoint is already up, nothing to do.
  if _rdp_endpoint_ready "$port"; then
    print -r -- "✅ Ready: http://127.0.0.1:$port"
    return 0
  fi

  # 1) Port check
  typeset port_info=''
  port_info="$(_port_in_use "$port" || true)"
  if [[ -n "$port_info" ]]; then
    print -r -- "⚠️ Port $port is already in use:"
    print -r -- "$port_info"
    if ! _confirm_or_abort "Proceed to kill the process(es) using port $port?"; then return 1; fi
    # Try killing the listener by PID (lsof first column includes PID in second field)
    typeset -a pids=()
    pids=("${(@f)$(lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | awk 'NR>1{print $2}' | sort -u)}")
    if (( ${#pids[@]} > 0 )); then
      kill -- "${pids[@]}" >/dev/null 2>&1 || true
      sleep 0.2
      # If still listening, force kill
      if _port_in_use "$port" >/dev/null 2>&1; then
        kill -9 -- "${pids[@]}" >/dev/null 2>&1 || true
      fi
    fi

    if _rdp_endpoint_ready "$port"; then
      print -r -- "✅ Ready: http://127.0.0.1:$port"
      return 0
    fi
  fi

  # 2) If using a dedicated profile and it's already running, restarting may be required.
  if [[ -n "$user_data_dir" ]]; then
    command mkdir -p -- "$user_data_dir" >/dev/null 2>&1 || {
      print -u2 -r -- "❌ Failed to create profile dir: $user_data_dir"
      return 1
    }

    # If any Chrome is running, it may be using this profile implicitly; stop it first.
    if _browser_running "$app_name" "$exe_path"; then
      print -r -- "⚠️ $app_name is running; need to stop it before relaunching with --user-data-dir."
      if ! _confirm_or_abort "Quit $app_name now to relaunch with remote debugging ($port)?"; then
        return 1
      fi

      if ! _quit_app_gracefully "$app_name"; then
        print -r -- "⚠️ $app_name did not quit in time."
        if ! _confirm_or_abort "Force kill $app_name processes?"; then
          return 1
        fi
        _force_kill_by_path "$exe_path"
        _kill_all_chrome_processes "$app_name" "$exe_path"
        sleep 0.2
      fi

      if ! _wait_for_browser_exit "$app_name" "$exe_path"; then
        print -r -- "⚠️ $app_name processes are still exiting; attempting force kill."
        _kill_all_chrome_processes "$app_name" "$exe_path"
        sleep 0.2
      fi
    fi

    _cleanup_singleton_locks "$user_data_dir"

    typeset -a profile_pids=()
    profile_pids=("${(@f)$(pgrep -f -- "--user-data-dir=${user_data_dir}" 2>/dev/null || true)}")
    if (( ${#profile_pids[@]} > 0 )); then
      print -r -- "⚠️ $app_name is already running for profile:"
      print -r -- "   - profile: $user_data_dir"
      print -r -- "   Restart may be required to apply remote debugging flags."
      if ! _confirm_or_abort "Kill that profile instance now to relaunch with remote debugging ($port)?"; then
        return 1
      fi
      kill -- "${profile_pids[@]}" >/dev/null 2>&1 || true
      sleep 0.2
      kill -9 -- "${profile_pids[@]}" >/dev/null 2>&1 || true
      sleep 0.2
    fi
  else
    # Using the user's default profile; need to quit running instances to apply flags.
    if _browser_running "$app_name" "$exe_path"; then
      print -r -- "⚠️ $app_name is already running."
      print -r -- "   Starting a new process may NOT apply --remote-debugging-port."
      if ! _confirm_or_abort "Quit $app_name now to relaunch with remote debugging ($port)?"; then
        return 1
      fi

      if ! _quit_app_gracefully "$app_name"; then
        print -r -- "⚠️ $app_name did not quit in time."
        if ! _confirm_or_abort "Force kill $app_name processes?"; then
          return 1
        fi
        _force_kill_by_path "$exe_path"
        _kill_all_chrome_processes "$app_name" "$exe_path"
        sleep 0.2
      fi

      if ! _wait_for_browser_exit "$app_name" "$exe_path"; then
        print -r -- "⚠️ $app_name processes are still exiting; attempting force kill."
        _kill_all_chrome_processes "$app_name" "$exe_path"
        sleep 0.2
      fi
    fi

    # Clean up stale locks for the default profile to avoid silent handoff/bounce.
    if [[ "$app_name" == "Google Chrome" ]]; then
      _cleanup_singleton_locks "$CHROME_DEFAULT_PROFILE_DIR"
    fi
  fi

  # 3) Launch
  print -r -- "🚀 Launching $app_name with remote debugging:"
  print -r -- "   - address: 127.0.0.1"
  print -r -- "   - port:    $port"
  if [[ -n "$user_data_dir" ]]; then
    print -r -- "   - profile: $user_data_dir"
  else
    print -r -- "   - profile: existing default (no --user-data-dir)"
  fi

  typeset -a launch_args=()
  launch_args=(
    --remote-debugging-address=127.0.0.1
    --remote-debugging-port="$port"
    --no-first-run
    --no-default-browser-check
  )
  if [[ -n "$user_data_dir" ]]; then
    launch_args+=(--user-data-dir="$user_data_dir")
  fi

  typeset launch_stdout="/dev/null"
  if (( rdp_debug == 1 )); then
    command mkdir -p -- "${rdp_debug_log:h}" >/dev/null 2>&1 || true
    launch_stdout="$rdp_debug_log"
    print -r -- "📝 Debug log: $launch_stdout"
  fi

  typeset -i launch_cmd_status=0
  if ! "$exe_path" "${launch_args[@]}" >"$launch_stdout" 2>&1 &!; then
    launch_cmd_status=$?
    print -r -- "⚠️ Direct launch exited with status $launch_cmd_status; will verify/fallback."
  fi

  # 4) Quick verify (best-effort)
  typeset -i i=0
  for i in {1..300}; do
    if _rdp_endpoint_ready "$port"; then
      print -r -- "✅ Ready: http://127.0.0.1:$port"
      return 0
    fi
    sleep 0.1
  done

  if _port_in_use "$port" >/dev/null 2>&1; then
    print -r -- "⚠️ Port $port is listening, but DevTools endpoint is not responding yet:"
    print -r -- "   http://127.0.0.1:$port/json/version"
    print -r -- "   It may be a non-Chrome process, or the browser is still starting."
  else
    print -r -- "⚠️ Launched, but port $port is not listening yet."
    print -r -- "   You can check with: lsof -nP -iTCP:$port -sTCP:LISTEN"
  fi

  # 5) Fallback: try macOS LaunchServices (helps when direct exec is sandboxed)
  if command -v open >/dev/null 2>&1; then
    print -r -- "↪️ Retrying via: open -na \"$app_name\" --args …"
    if ! open -na "$app_name" --args "${launch_args[@]}" >/dev/null 2>&1; then
      print -u2 -r -- "❌ Fallback launch failed via open -na (status $?)"
      return 1
    fi
    for i in {1..50}; do
      if _rdp_endpoint_ready "$port"; then
        print -r -- "✅ Ready (fallback): http://127.0.0.1:$port"
        return 0
      fi
      sleep 0.1
    done
    print -r -- "⚠️ Fallback launch did not expose DevTools endpoint on $port."
  fi

  if (( rdp_debug == 1 )) && [[ -f "$rdp_debug_log" ]]; then
    print -r -- "📝 Launch log tail:"
    command tail -n 20 -- "$rdp_debug_log" 2>/dev/null || true
  fi

  return 1
}

# ---- public commands --------------------------------------------------------

# chrome-rdp
# Launch Google Chrome with DevTools remote debugging enabled.
# Usage: chrome-rdp
# Examples:
#   chrome-rdp
#   CHROME_REMOTE_DEBUG_PORT_DEFAULT=9222 chrome-rdp
# Env:
# - CHROME_REMOTE_DEBUG_PORT_DEFAULT: remote debugging port (default: 19222).
# - CHROME_REMOTE_DEBUG_USER_DATA_DIR: explicit profile dir (skip auto-caching).
# - RDP_USE_ISOLATED_PROFILE_ENABLED: when true, use CHROME_REMOTE_DEBUG_PROFILE_DIR_DEFAULT.
# - CHROME_REMOTE_DEBUG_PROFILE_DIR_DEFAULT: isolated profile dir (default: ~/.codex/chrome-profile).
# - RDP_ASSUME_YES_ENABLED: when true, auto-confirm prompts.
# - RDP_DEBUG_ENABLED: when true, write debug log.
# - RDP_DEBUG_LOG: debug log path.
# Safety:
# - May quit and/or kill Chrome processes to apply remote debugging flags.
chrome-rdp() {
  emulate -L zsh
  setopt pipe_fail err_return nounset

  # Profile selection:
  #   1) If CHROME_REMOTE_DEBUG_USER_DATA_DIR is set, use it.
  #   2) Else if RDP_USE_ISOLATED_PROFILE_ENABLED=true, use default isolated profile dir.
  #   3) Else if CHROME_REMOTE_DEBUG_USER_DATA_DIR_DEFAULT is set, use it.
  #   4) Else use a cached copy of Default profile (with Local State).
  typeset user_data_dir=''
  if [[ -n "${CHROME_REMOTE_DEBUG_USER_DATA_DIR-}" ]]; then
    user_data_dir="${CHROME_REMOTE_DEBUG_USER_DATA_DIR}"
  elif zsh_env::is_true "${RDP_USE_ISOLATED_PROFILE_ENABLED-}" "RDP_USE_ISOLATED_PROFILE_ENABLED"; then
    user_data_dir="${CHROME_REMOTE_DEBUG_PROFILE_DIR_DEFAULT}"
  elif [[ -n "${CHROME_REMOTE_DEBUG_USER_DATA_DIR_DEFAULT-}" ]]; then
    user_data_dir="${CHROME_REMOTE_DEBUG_USER_DATA_DIR_DEFAULT}"
  else
    # Auto-cache default profile into cache dir, then use it.
    if _ensure_cached_default_profile "Google Chrome" "$CHROME_DEFAULT_PROFILE_DIR/Default" "$CHROME_PROFILE_CACHE_DEFAULT_DIR" "$CHROME_DEFAULT_LOCAL_STATE"; then
      user_data_dir="$CHROME_PROFILE_CACHE_DIR"
    else
      return 1
    fi
  fi

  _launch_rdp \
    "Google Chrome" \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "${CHROME_REMOTE_DEBUG_PORT_DEFAULT}" \
    "$user_data_dir"
}
