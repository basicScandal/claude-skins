#!/bin/bash
# Claude Skins — activate a skin
# Usage: activate.sh <skin-name>
# Called by SessionStart hook or /skin command

set -euo pipefail

SKINS_DIR="$HOME/.claude/skins"
ENGINE_DIR="$SKINS_DIR/engine"
RESTORE_FILE="/tmp/claude-skin-restore"

# Load pure-bash YAML parser
# shellcheck source=engine/parse-yaml.sh
source "$ENGINE_DIR/parse-yaml.sh"

skin_name="${1:-}"

# If no name given, read from config
if [[ -z "$skin_name" ]]; then
  if [[ -f "$ENGINE_DIR/config.yaml" ]]; then
    skin_name=$(get_yaml_value "$ENGINE_DIR/config.yaml" "default_skin" 2>/dev/null || echo "default")
    [[ -z "$skin_name" ]] && skin_name="default"
  else
    skin_name="default"
  fi
fi

# Skip activation for default skin
[[ "$skin_name" == "default" ]] && exit 0

skin_file="$SKINS_DIR/${skin_name}.yaml"
default_file="$SKINS_DIR/default.yaml"

if [[ ! -f "$skin_file" ]]; then
  echo "Skin not found: $skin_name"
  echo "Available skins:"
  for f in "$SKINS_DIR"/*.yaml; do
    [[ "$(basename "$f")" == "default.yaml" ]] && continue
    basename "$f" .yaml
  done
  exit 1
fi

# Helper: get value with fallback to default.yaml
yval() {
  get_yaml_value_with_default "$skin_file" "$default_file" "$1"
}

# Helper: get block scalar with fallback to default.yaml
yblock() {
  get_yaml_block_with_default "$skin_file" "$default_file" "$1"
}

# --- Save terminal state marker for restore ---
echo "reset" > "$RESTORE_FILE"

# --- Apply terminal colors via AppleScript (bypasses PTY, works from Claude Code hooks) ---
# Claude Code hook subprocesses have no TTY; OSC sequences via stdout are also intercepted
# and stripped by Claude Code's TUI renderer. osascript communicates via Apple Events
# directly to iTerm2, bypassing the PTY entirely.
hex_to_16bit() {
  local hex="${1#\#}"
  local r=$((16#${hex:0:2} * 257))
  local g=$((16#${hex:2:2} * 257))
  local b=$((16#${hex:4:2} * 257))
  echo "$r, $g, $b"
}

iterm_set_color() {
  local property="$1"
  local hex="$2"
  [[ -z "$hex" ]] && return
  local rgb
  rgb=$(hex_to_16bit "$hex")
  osascript -e "tell application \"iTerm2\" to tell current session of current window to set $property to {$rgb}" 2>/dev/null || true
}

bg=$(yval "terminal.background")
fg=$(yval "terminal.foreground")
cursor=$(yval "terminal.cursor")

iterm_set_color "background color" "$bg"
iterm_set_color "foreground color" "$fg"
iterm_set_color "cursor color" "$cursor"

palette_names=("black" "red" "green" "yellow" "blue" "magenta" "cyan" "white")
ansi_properties=("ansi black color" "ansi red color" "ansi green color" "ansi yellow color" "ansi blue color" "ansi magenta color" "ansi cyan color" "ansi white color")
for i in "${!palette_names[@]}"; do
  color=$(get_yaml_value "$skin_file" "terminal.palette.${palette_names[$i]}")
  iterm_set_color "${ansi_properties[$i]}" "$color"
done

# --- Write active skin ---
echo "$skin_name" > "$ENGINE_DIR/current"

# --- Symlink personality ---
personality_file="$SKINS_DIR/personalities/${skin_name}.md"
output_styles_dir="$HOME/.claude/output-styles"
mkdir -p "$output_styles_dir"
# Remove old skin symlinks
find "$output_styles_dir" -name "skin-*.md" -type l -delete 2>/dev/null || true
if [[ -f "$personality_file" ]]; then
  ln -sf "$personality_file" "$output_styles_dir/skin-${skin_name}.md"
fi

# --- Print banner to stdout (shown in hook output / terminal) ---
banner=$(yblock "branding.banner")
hero=$(yblock "branding.hero")
welcome=$(yval "branding.welcome")

echo ""
if [[ -n "$hero" ]]; then
  echo -e "$hero"
  echo ""
fi
if [[ -n "$banner" ]]; then
  echo -e "$banner"
  echo ""
fi
if [[ -n "$welcome" ]]; then
  echo -e "\033[2m$welcome\033[0m"
fi
echo ""
