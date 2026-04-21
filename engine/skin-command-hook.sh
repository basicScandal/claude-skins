#!/bin/bash
# Claude Skins — UserPromptSubmit hook
# Intercepts /skin commands
# Input: JSON with user's prompt on stdin

ENGINE_DIR="$HOME/.claude/skins/engine"
SKINS_DIR="$HOME/.claude/skins"

input=$(cat)

# Extract the user's message
message=$(echo "$input" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('prompt', d.get('message', '')))
except: print('')
" 2>/dev/null || echo "")

# Only handle /skin commands
[[ ! "$message" =~ ^/skin ]] && exit 0

# Parse the command
args="${message#/skin}"
args="${args## }"  # trim leading space

case "$args" in
  "")
    # List available skins
    current=$(cat "$ENGINE_DIR/current" 2>/dev/null || echo "default")
    echo "Available skins:"
    for f in "$SKINS_DIR"/*.yaml; do
      name=$(basename "$f" .yaml)
      [[ "$name" == "default" ]] && continue
      desc=$(python3 -c "
import yaml
with open('$f') as fh:
    print(yaml.safe_load(fh).get('description', ''))
" 2>/dev/null || echo "")
      if [[ "$name" == "$current" ]]; then
        echo "  → $name — $desc"
      else
        echo "    $name — $desc"
      fi
    done
    # Block the prompt from going to Claude
    exit 2
    ;;
  reset)
    "$ENGINE_DIR/deactivate.sh"
    echo "Skin deactivated. Terminal restored."
    exit 2
    ;;
  default)
    current=$(cat "$ENGINE_DIR/current" 2>/dev/null || echo "default")
    python3 -c "
import yaml
with open('$ENGINE_DIR/config.yaml') as f:
    d = yaml.safe_load(f)
d['default_skin'] = '$current'
with open('$ENGINE_DIR/config.yaml', 'w') as f:
    yaml.dump(d, f, default_flow_style=False)
"
    echo "Default skin set to: $current"
    exit 2
    ;;
  *)
    # Switch to named skin
    "$ENGINE_DIR/activate.sh" "$args"
    exit 2
    ;;
esac
