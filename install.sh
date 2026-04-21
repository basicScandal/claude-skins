#!/bin/bash
# Claude Skins — installer
# Copies skins, engine, and personalities into ~/.claude/skins/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude/skins"

echo "Installing Claude Skins..."

# Check for Python + PyYAML
if ! python3 -c "import yaml" 2>/dev/null; then
  echo "Error: Python 3 with PyYAML is required."
  echo "Install it: pip install pyyaml"
  exit 1
fi

# Create directories
mkdir -p "$DEST/engine" "$DEST/personalities"

# Copy skins
cp "$SCRIPT_DIR/skins/"*.yaml "$DEST/"
echo "  Copied skin definitions"

# Copy engine
cp "$SCRIPT_DIR/engine/"*.sh "$DEST/engine/"
chmod +x "$DEST/engine/"*.sh
echo "  Copied engine scripts"

# Copy personalities
cp "$SCRIPT_DIR/personalities/"*.md "$DEST/personalities/"
echo "  Copied personality files"

# Initialize config if not present
if [[ ! -f "$DEST/engine/config.yaml" ]]; then
  echo "default_skin: nebula" > "$DEST/engine/config.yaml"
  echo "  Created default config (skin: nebula)"
fi

# Initialize current if not present
if [[ ! -f "$DEST/engine/current" ]]; then
  echo "default" > "$DEST/engine/current"
fi

echo ""
echo "Done! Next steps:"
echo ""
echo "  1. Add hooks to ~/.claude/settings.json (see README.md)"
echo "  2. Create the /skin skill (see engine/SKILL.md)"
echo "  3. Restart Claude Code"
echo "  4. Run: /skin nebula"
echo ""
