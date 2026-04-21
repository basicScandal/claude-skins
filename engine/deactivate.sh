#!/bin/bash
# Claude Skins — deactivate/restore terminal
# Called by SessionEnd hook or /skin reset

set -euo pipefail

ENGINE_DIR="$HOME/.claude/skins/engine"
RESTORE_FILE="/tmp/claude-skin-restore"
OUTPUT_STYLES_DIR="$HOME/.claude/output-styles"

# Print goodbye message from current skin
current_skin=""
if [[ -f "$ENGINE_DIR/current" ]]; then
  current_skin=$(cat "$ENGINE_DIR/current" 2>/dev/null || echo "")
fi

if [[ -n "$current_skin" && "$current_skin" != "default" ]]; then
  skin_file="$HOME/.claude/skins/${current_skin}.yaml"
  if [[ -f "$skin_file" ]]; then
    goodbye=$(python3 -c "
import yaml
with open('$skin_file') as f:
    data = yaml.safe_load(f)
print(data.get('branding', {}).get('goodbye', ''))" 2>/dev/null || echo "")
    if [[ -n "$goodbye" ]]; then
      echo -e "\033[2m$goodbye\033[0m"
    fi
  fi
fi

# Restore terminal colors via /dev/tty
if [[ -f "$RESTORE_FILE" && -e /dev/tty ]]; then
  {
    printf '\033]110\007'   # reset foreground
    printf '\033]111\007'   # reset background
    printf '\033]112\007'   # reset cursor
    # Reset ANSI palette
    for i in {0..7}; do
      printf '\033]104;%d\007' "$i"
    done
    # Reset terminal title
    printf '\033]0;\007'
  } > /dev/tty 2>/dev/null || true
  rm -f "$RESTORE_FILE"
fi

# Remove skin personality symlinks
find "$OUTPUT_STYLES_DIR" -name "skin-*.md" -type l -delete 2>/dev/null || true

# Reset current skin
echo "default" > "$ENGINE_DIR/current"
