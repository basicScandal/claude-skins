#!/bin/bash
# Claude Skins — PostToolUse hook
# Plays themed sounds per tool action
# Input: JSON from Claude Code PostToolUse hook on stdin

ENGINE_DIR="$HOME/.claude/skins/engine"
SKINS_DIR="$HOME/.claude/skins"

# Load cross-platform sound abstraction (defines play_sound())
# shellcheck source=engine/play-sound.sh
source "$ENGINE_DIR/play-sound.sh" 2>/dev/null || true

# Read hook input
input=$(cat)

# Check if skins are active
SKIN_NAME=""
if [[ -f "$ENGINE_DIR/current" ]]; then
  SKIN_NAME=$(cat "$ENGINE_DIR/current" 2>/dev/null || echo "")
fi

[[ -z "$SKIN_NAME" || "$SKIN_NAME" == "default" ]] && exit 0

# Check skin file exists
SKIN_FILE="$SKINS_DIR/${SKIN_NAME}.yaml"
[[ ! -f "$SKIN_FILE" ]] && exit 0

# Cache parsed tool events (60s TTL)
TOOL_CACHE="/tmp/claude-skin-tools-${SKIN_NAME}"
TOOL_CACHE_AGE=999
if [[ -f "$TOOL_CACHE" ]]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    TOOL_CACHE_AGE=$(( $(date +%s) - $(stat -f %m "$TOOL_CACHE") ))
  else
    TOOL_CACHE_AGE=$(( $(date +%s) - $(stat -c %Y "$TOOL_CACHE") ))
  fi
fi

if [[ "$TOOL_CACHE_AGE" -gt 60 ]]; then
  # shellcheck source=engine/parse-yaml.sh
  source "$ENGINE_DIR/parse-yaml.sh"
  {
    get_yaml_value "$SKIN_FILE" "tools.sounds"
    # Events: one line per event as "event_name:sound:icon"
    for evt in file_written command_run error search; do
      sound=$(get_yaml_event_field "$SKIN_FILE" "$evt" "sound")
      icon=$(get_yaml_event_field  "$SKIN_FILE" "$evt" "icon")
      echo "${evt}:${sound}:${icon}"
    done
  } > "$TOOL_CACHE" 2>/dev/null || exit 0
fi

[[ ! -f "$TOOL_CACHE" ]] && exit 0

# Read cache: first line = sounds enabled, then event lines "event:sound:icon"
sounds_enabled=$(head -1 "$TOOL_CACHE")
[[ "$sounds_enabled" != "true" ]] && exit 0

# Map Claude Code tool names to skin event types
tool_name=$(echo "$input" | jq -r '.tool_name // .tool // ""' 2>/dev/null || echo "")

# Map tool to event type
event=""
case "$tool_name" in
  Write|Edit|MultiEdit|NotebookEdit) event="file_written" ;;
  Bash) event="command_run" ;;
  Grep|Glob) event="search" ;;
  *) exit 0 ;;
esac

# Look up sound for this event from cache (grep the event:sound:icon line)
sound=""
while IFS= read -r line; do
  [[ $((++_line_no)) -eq 1 ]] && continue   # skip sounds_enabled line
  if [[ "${line%%:*}" == "$event" ]]; then
    rest="${line#*:}"
    sound="${rest%%:*}"
    break
  fi
done < "$TOOL_CACHE"
unset _line_no

# Play sound (async, non-blocking, cross-platform)
if [[ -n "$sound" ]]; then
  play_sound "$sound"
fi

exit 0
