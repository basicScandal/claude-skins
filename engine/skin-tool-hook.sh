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

# Check sounds enabled
SKIN_FILE="$SKINS_DIR/${SKIN_NAME}.yaml"
[[ ! -f "$SKIN_FILE" ]] && exit 0

# Cache parsed tool events
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
  python3 -c "
import yaml, json
with open('$SKIN_FILE') as f:
    d = yaml.safe_load(f)
tools = d.get('tools', {})
print(json.dumps({
    'sounds': tools.get('sounds', False),
    'events': tools.get('events', {})
}))
" > "$TOOL_CACHE" 2>/dev/null || exit 0
fi

[[ ! -f "$TOOL_CACHE" ]] && exit 0

# Check if sounds enabled
sounds_enabled=$(python3 -c "
import json
with open('$TOOL_CACHE') as f:
    print(json.load(f).get('sounds', False))
" 2>/dev/null || echo "False")

[[ "$sounds_enabled" != "True" ]] && exit 0

# Map Claude Code tool names to skin event types
tool_name=$(echo "$input" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_name', d.get('tool', '')))
except: print('')
" 2>/dev/null || echo "")

# Map tool to event type
event=""
case "$tool_name" in
  Write|Edit|MultiEdit|NotebookEdit) event="file_written" ;;
  Bash) event="command_run" ;;
  Grep|Glob) event="search" ;;
  *) exit 0 ;;
esac

# Get sound for this event
sound=$(python3 -c "
import json
with open('$TOOL_CACHE') as f:
    events = json.load(f).get('events', {})
evt = events.get('$event', {})
print(evt.get('sound', ''))
" 2>/dev/null || echo "")

# Play sound (async, non-blocking, cross-platform)
if [[ -n "$sound" ]]; then
  play_sound "$sound"
fi

exit 0
