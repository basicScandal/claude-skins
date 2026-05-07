#!/bin/bash
# Claude Skins — UserPromptSubmit hook
# Intercepts /skin commands
# Input: JSON with user's prompt on stdin

ENGINE_DIR="$HOME/.claude/skins/engine"
SKINS_DIR="$HOME/.claude/skins"

# Load pure-bash YAML parser
# shellcheck source=engine/parse-yaml.sh
source "$ENGINE_DIR/parse-yaml.sh"

input=$(cat)

# Extract the user's message using jq (already a dependency via statusline)
message=$(echo "$input" | jq -r '.prompt // .message // ""' 2>/dev/null || echo "")

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
      desc=$(get_yaml_value "$f" "description")
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
    config_file="$ENGINE_DIR/config.yaml"
    # Update or create the default_skin key.
    # config.yaml is a minimal single-key file: "default_skin: value"
    if [[ -f "$config_file" ]]; then
      # Replace existing default_skin line, or append if not present
      if grep -q "^default_skin:" "$config_file"; then
        # Use a temp file for in-place edit without sed -i (portability)
        tmp=$(mktemp)
        while IFS= read -r line; do
          if [[ "$line" =~ ^default_skin: ]]; then
            echo "default_skin: $current"
          else
            echo "$line"
          fi
        done < "$config_file" > "$tmp"
        mv "$tmp" "$config_file"
      else
        echo "default_skin: $current" >> "$config_file"
      fi
    else
      echo "default_skin: $current" > "$config_file"
    fi
    echo "Default skin set to: $current"
    exit 2
    ;;
  *)
    # Switch to named skin
    "$ENGINE_DIR/activate.sh" "$args"
    exit 2
    ;;
esac
