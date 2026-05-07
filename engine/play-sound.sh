#!/bin/bash
# play-sound.sh — Cross-platform sound abstraction layer for claude-skins
#
# Usage: source play-sound.sh && play_sound "Tink"
#
# Accepts a macOS system sound name and plays the closest available
# equivalent on the current platform. Never exits with an error —
# if no sound system is available, this is a silent no-op.

# Map macOS sound names to PulseAudio/freedesktop event sound names.
# Fallback order: named event → generic event → built-in beep → silence.
_macos_to_freedesktop() {
  local name="$1"
  case "$name" in
    Basso)     echo "dialog-error" ;;
    Blow)      echo "dialog-warning" ;;
    Bottle)    echo "message" ;;
    Frog)      echo "message" ;;
    Funk)      echo "dialog-warning" ;;
    Glass)     echo "complete" ;;
    Hero)      echo "complete" ;;
    Morse)     echo "message" ;;
    Ping)      echo "bell" ;;
    Pop)       echo "bell" ;;
    Purr)      echo "complete" ;;
    Sosumi)    echo "dialog-error" ;;
    Submarine) echo "message" ;;
    Tink)      echo "bell" ;;
    *)         echo "bell" ;;
  esac
}

# Detect WSL (Windows Subsystem for Linux)
_is_wsl() {
  [[ -f /proc/version ]] && grep -qi "microsoft\|wsl" /proc/version 2>/dev/null
}

# Play a sound by macOS sound name.
# Background execution and error suppression are handled here so callers
# don't have to remember the & and 2>/dev/null dance.
play_sound() {
  local sound_name="$1"
  [[ -z "$sound_name" ]] && return 0

  # ── macOS ──────────────────────────────────────────────────────────────
  if [[ "$OSTYPE" == "darwin"* ]]; then
    local aiff="/System/Library/Sounds/${sound_name}.aiff"
    if [[ -f "$aiff" ]] && command -v afplay &>/dev/null; then
      afplay "$aiff" &>/dev/null &
      disown
    fi
    return 0
  fi

  # ── Linux / WSL ────────────────────────────────────────────────────────
  local fd_name
  fd_name="$(_macos_to_freedesktop "$sound_name")"

  # WSL: use PowerShell to emit a simple beep via .NET — no audio drivers needed
  if _is_wsl && command -v powershell.exe &>/dev/null; then
    powershell.exe -NoProfile -NonInteractive -Command \
      "[console]::beep(800,80)" &>/dev/null &
    disown
    return 0
  fi

  # PulseAudio: try paplay with a freedesktop sound theme first
  if command -v paplay &>/dev/null; then
    # Look for the sound in common theme directories
    local sound_dirs=(
      "/usr/share/sounds/freedesktop/stereo"
      "/usr/share/sounds/ubuntu/stereo"
      "/usr/share/sounds/gnome/default/alerts"
      "/usr/share/sounds"
    )
    local ext
    for ext in oga ogg wav; do
      local dir
      for dir in "${sound_dirs[@]}"; do
        local candidate="${dir}/${fd_name}.${ext}"
        if [[ -f "$candidate" ]]; then
          paplay "$candidate" &>/dev/null &
          disown
          return 0
        fi
      done
    done

    # No themed file found — fall through to ALSA / console beep
  fi

  # ALSA: aplay fallback — play a very short WAV if one exists, or skip
  if command -v aplay &>/dev/null; then
    local alsa_dirs=(
      "/usr/share/sounds/freedesktop/stereo"
      "/usr/share/sounds"
    )
    local dir
    for dir in "${alsa_dirs[@]}"; do
      local candidate="${dir}/${fd_name}.wav"
      if [[ -f "$candidate" ]]; then
        aplay -q "$candidate" &>/dev/null &
        disown
        return 0
      fi
    done
  fi

  # Last resort: ANSI/VT bell via the terminal (silent if bell is muted)
  if [[ -t 1 ]]; then
    printf '\a' &>/dev/null
  fi

  return 0
}
