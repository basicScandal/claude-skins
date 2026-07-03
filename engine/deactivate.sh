#!/bin/bash
# Claude Skins — deactivate/restore terminal
# Called by SessionEnd hook or /skin reset

set -euo pipefail

ENGINE_DIR="$HOME/.claude/skins/engine"
RESTORE_FILE="/tmp/claude-skin-restore"
OUTPUT_STYLES_DIR="$HOME/.claude/output-styles"

# Load pure-bash YAML parser
# shellcheck source=engine/parse-yaml.sh
source "$ENGINE_DIR/parse-yaml.sh"

# Print goodbye message from current skin
current_skin=""
if [[ -f "$ENGINE_DIR/current" ]]; then
  current_skin=$(cat "$ENGINE_DIR/current" 2>/dev/null || echo "")
fi

if [[ -n "$current_skin" && "$current_skin" != "default" ]]; then
  skin_file="$HOME/.claude/skins/${current_skin}.yaml"
  if [[ -f "$skin_file" ]]; then
    goodbye=$(get_yaml_value "$skin_file" "branding.goodbye")
    if [[ -n "$goodbye" ]]; then
      echo -e "\033[2m$goodbye\033[0m"
    fi
  fi
fi

# Restore terminal colors via AppleScript
if [[ -f "$RESTORE_FILE" ]]; then
  osascript 2>/dev/null <<'APPLESCRIPT' || true
tell application "iTerm2"
  tell current session of current window
    set background color to {0, 0, 0}
    set foreground color to {65535, 65535, 65535}
    set cursor color to {65535, 65535, 65535}
    set ansi black color to {0, 0, 0}
    set ansi red color to {52428, 0, 0}
    set ansi green color to {0, 52428, 0}
    set ansi yellow color to {52428, 52428, 0}
    set ansi blue color to {0, 0, 52428}
    set ansi magenta color to {52428, 0, 52428}
    set ansi cyan color to {0, 52428, 52428}
    set ansi white color to {52428, 52428, 52428}
  end tell
end tell
APPLESCRIPT
  rm -f "$RESTORE_FILE"
fi

# Remove skin personality symlinks
find "$OUTPUT_STYLES_DIR" -name "skin-*.md" -type l -delete 2>/dev/null || true

# Only clear skin state on explicit reset (not on normal session end)
if [[ "${1:-}" == "--reset" ]]; then
  echo "default" > "$ENGINE_DIR/current"
fi
