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

# --- Apply terminal colors via /dev/tty (reaches actual terminal) ---
bg=$(yval "terminal.background")
fg=$(yval "terminal.foreground")
cursor=$(yval "terminal.cursor")

if [[ -e /dev/tty ]]; then
  {
    [[ -n "$bg" ]] && printf '\033]11;%s\007' "$bg"
    [[ -n "$fg" ]] && printf '\033]10;%s\007' "$fg"
    [[ -n "$cursor" ]] && printf '\033]12;%s\007' "$cursor"

    # Apply palette colors (ANSI 0-7)
    palette_colors=("black" "red" "green" "yellow" "blue" "magenta" "cyan" "white")
    for i in "${!palette_colors[@]}"; do
      color=$(get_yaml_value "$skin_file" "terminal.palette.${palette_colors[$i]}")
      [[ -n "$color" ]] && printf '\033]4;%d;%s\007' "$i" "$color"
    done

    # Set terminal title
    printf '\033]0;Claude ◆ %s\007' "$skin_name"
  } > /dev/tty 2>/dev/null || true
fi

# --- Apply terminal colors for Ghostty via AppleScript (Apple Events) ---
# Claude Code (v2.1.139+) runs hook/tool subprocesses with no controlling
# terminal, so OSC sequences via /dev/tty and via stdout are both dropped.
# Ghostty is AppleScript-scriptable: write the palette into its config and
# trigger an out-of-band reload, which needs no TTY. No-op on other terminals.
if [[ "$(uname)" == "Darwin" ]] && { [[ "${TERM_PROGRAM:-}" == "ghostty" ]] || [[ -n "${GHOSTTY_RESOURCES_DIR:-}" ]]; }; then
  ghostty_config="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
  mkdir -p "$(dirname "$ghostty_config")"

  # Rebuild our managed block, preserving any user config outside the markers
  gtmp=$(mktemp)
  if [[ -f "$ghostty_config" ]]; then
    awk '
      /^# >>> claude-skins/ {skip=1}
      skip==0 {print}
      /^# <<< claude-skins/ {skip=0; next}
    ' "$ghostty_config" > "$gtmp"
  fi
  {
    echo "# >>> claude-skins (managed) — overwritten on skin switch; delete file to reset"
    [[ -n "$bg" ]]     && echo "background = $bg"
    [[ -n "$fg" ]]     && echo "foreground = $fg"
    [[ -n "$cursor" ]] && echo "cursor-color = $cursor"
    g_palette=("black" "red" "green" "yellow" "blue" "magenta" "cyan" "white")
    for i in "${!g_palette[@]}"; do
      color=$(get_yaml_value "$skin_file" "terminal.palette.${g_palette[$i]}")
      [[ -n "$color" ]] && echo "palette = ${i}=${color}"
    done
    echo "# <<< claude-skins (managed)"
  } >> "$gtmp"
  mv "$gtmp" "$ghostty_config"

  # Live reload, out-of-band (works without a TTY); silent on any failure
  osascript -e 'tell application "Ghostty" to perform action "reload_config" on (terminal 1 of front window)' >/dev/null 2>&1 || true
fi

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
