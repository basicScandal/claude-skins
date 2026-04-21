#!/bin/bash
# Claude Skins — activate a skin
# Usage: activate.sh <skin-name>
# Called by SessionStart hook or /skin command

set -euo pipefail

SKINS_DIR="$HOME/.claude/skins"
ENGINE_DIR="$SKINS_DIR/engine"
RESTORE_FILE="/tmp/claude-skin-restore"

skin_name="${1:-}"

# If no name given, read from config
if [[ -z "$skin_name" ]]; then
  if [[ -f "$ENGINE_DIR/config.yaml" ]]; then
    skin_name=$(python3 -c "
import yaml
with open('$ENGINE_DIR/config.yaml') as f:
    print(yaml.safe_load(f).get('default_skin', 'default'))
" 2>/dev/null || echo "default")
  else
    skin_name="default"
  fi
fi

# Skip activation for default skin
[[ "$skin_name" == "default" ]] && exit 0

skin_file="$SKINS_DIR/${skin_name}.yaml"

if [[ ! -f "$skin_file" ]]; then
  echo "Skin not found: $skin_name"
  echo "Available skins:"
  for f in "$SKINS_DIR"/*.yaml; do
    [[ "$(basename "$f")" == "default.yaml" ]] && continue
    basename "$f" .yaml
  done
  exit 1
fi

# Parse skin YAML
skin_data=$(python3 -c "
import yaml, json
with open('$skin_file') as f:
    data = yaml.safe_load(f)
# Merge with defaults
try:
    with open('$SKINS_DIR/default.yaml') as f:
        defaults = yaml.safe_load(f)
    def merge(base, override):
        for k, v in override.items():
            if isinstance(v, dict) and isinstance(base.get(k), dict):
                merge(base[k], v)
            else:
                base[k] = v
        return base
    data = merge(defaults, data)
except FileNotFoundError:
    pass
print(json.dumps(data))
")

# Helper to extract JSON values
jval() {
  echo "$skin_data" | python3 -c "import sys,json; d=json.load(sys.stdin); keys='$1'.split('.'); v=d;
for k in keys: v=v.get(k,'') if isinstance(v,dict) else ''
print(v if v else '')"
}

# --- Save terminal state marker for restore ---
echo "reset" > "$RESTORE_FILE"

# --- Apply terminal colors via /dev/tty (reaches actual terminal) ---
bg=$(jval "terminal.background")
fg=$(jval "terminal.foreground")
cursor=$(jval "terminal.cursor")

if [[ -e /dev/tty ]]; then
  {
    [[ -n "$bg" ]] && printf '\033]11;%s\007' "$bg"
    [[ -n "$fg" ]] && printf '\033]10;%s\007' "$fg"
    [[ -n "$cursor" ]] && printf '\033]12;%s\007' "$cursor"

    # Apply palette colors (ANSI 0-7)
    palette_colors=("black" "red" "green" "yellow" "blue" "magenta" "cyan" "white")
    for i in "${!palette_colors[@]}"; do
      color=$(jval "terminal.palette.${palette_colors[$i]}")
      [[ -n "$color" ]] && printf '\033]4;%d;%s\007' "$i" "$color"
    done

    # Set terminal title
    printf '\033]0;Claude ◆ %s\007' "$skin_name"
  } > /dev/tty 2>/dev/null || true
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
banner=$(jval "branding.banner")
hero=$(jval "branding.hero")
welcome=$(jval "branding.welcome")

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
