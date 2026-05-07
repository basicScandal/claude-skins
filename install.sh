#!/bin/bash
# Claude Skins — installer
# Copies skins, engine, personalities into ~/.claude/skins/,
# auto-patches ~/.claude/settings.json with required hooks,
# and creates the /skin skill.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude/skins"
SETTINGS="$HOME/.claude/settings.json"
SKILL_DIR="$HOME/.claude/skills/skin"

# ── Prerequisites ────────────────────────────────────────────────────────────

if ! python3 -c "import yaml" 2>/dev/null; then
  echo "Error: Python 3 with PyYAML is required."
  echo "Install it: pip install pyyaml"
  exit 1
fi

if ! python3 -c "import json" 2>/dev/null; then
  echo "Error: Python 3 with json module is required (should be built-in)."
  exit 1
fi

# ── Copy files ───────────────────────────────────────────────────────────────

echo "Installing Claude Skins..."

mkdir -p "$DEST/engine" "$DEST/personalities"

cp "$SCRIPT_DIR/skins/"*.yaml "$DEST/"
echo "  Copied skin definitions"

cp "$SCRIPT_DIR/engine/"*.sh "$DEST/engine/"
chmod +x "$DEST/engine/"*.sh
echo "  Copied engine scripts"

cp "$SCRIPT_DIR/personalities/"*.md "$DEST/personalities/"
echo "  Copied personality files"

if [[ ! -f "$DEST/engine/config.yaml" ]]; then
  echo "default_skin: nebula" > "$DEST/engine/config.yaml"
  echo "  Created default config (skin: nebula)"
fi

if [[ ! -f "$DEST/engine/current" ]]; then
  echo "default" > "$DEST/engine/current"
fi

# ── Install /skin skill ──────────────────────────────────────────────────────

mkdir -p "$SKILL_DIR"
cp "$SCRIPT_DIR/engine/SKILL.md" "$SKILL_DIR/SKILL.md"
echo "  Created ~/.claude/skills/skin/SKILL.md"

# ── Patch settings.json ──────────────────────────────────────────────────────

echo "  Patching ~/.claude/settings.json..."

# Ensure settings.json exists
if [[ ! -f "$SETTINGS" ]]; then
  echo "{}" > "$SETTINGS"
fi

# Back up settings.json
cp "$SETTINGS" "${SETTINGS}.backup"
echo "  Backed up settings.json to settings.json.backup"

# Use Python to idempotently merge all required hooks and statusLine
python3 << PYEOF
import json, sys, os

settings_path = os.path.expanduser("~/.claude/settings.json")
skins_engine  = os.path.expanduser("~/.claude/skins/engine")

with open(settings_path) as f:
    cfg = json.load(f)

# ── Helpers ──────────────────────────────────────────────────────────────────

def has_command(hook_list, cmd_fragment):
    """Return True if any hook entry already contains cmd_fragment."""
    for entry in hook_list:
        for h in entry.get("hooks", []):
            if cmd_fragment in h.get("command", ""):
                return True
    return False

def ensure_hook(cfg, event, new_entry, cmd_fragment):
    """Add new_entry under cfg['hooks'][event] if cmd_fragment not already present."""
    cfg.setdefault("hooks", {}).setdefault(event, [])
    if not has_command(cfg["hooks"][event], cmd_fragment):
        cfg["hooks"][event].append(new_entry)
        return True
    return False

# ── SessionStart: activate.sh ────────────────────────────────────────────────

changed = False

r = ensure_hook(cfg, "SessionStart",
    {"hooks": [{"type": "command", "command": f"{skins_engine}/activate.sh"}]},
    "skins/engine/activate.sh")
if r:
    changed = True
    print("    Added SessionStart hook: activate.sh")
else:
    print("    SessionStart hook already present — skipped")

# ── SessionEnd: deactivate.sh ────────────────────────────────────────────────

r = ensure_hook(cfg, "SessionEnd",
    {"hooks": [{"type": "command", "command": f"{skins_engine}/deactivate.sh"}]},
    "skins/engine/deactivate.sh")
if r:
    changed = True
    print("    Added SessionEnd hook: deactivate.sh")
else:
    print("    SessionEnd hook already present — skipped")

# ── PostToolUse: skin-tool-hook.sh ───────────────────────────────────────────

r = ensure_hook(cfg, "PostToolUse",
    {
        "matcher": "Bash|Write|Edit|MultiEdit|Grep|Glob",
        "hooks": [{
            "type": "command",
            "command": f"{skins_engine}/skin-tool-hook.sh",
            "timeout": 5
        }]
    },
    "skins/engine/skin-tool-hook.sh")
if r:
    changed = True
    print("    Added PostToolUse hook: skin-tool-hook.sh")
else:
    print("    PostToolUse hook already present — skipped")

# ── statusLine ───────────────────────────────────────────────────────────────

existing_sl = cfg.get("statusLine", {})
existing_cmd = existing_sl.get("command", "") if isinstance(existing_sl, dict) else ""
if "skins/engine/statusline.sh" not in existing_cmd:
    cfg["statusLine"] = {
        "type": "command",
        "command": f"{skins_engine}/statusline.sh"
    }
    changed = True
    print("    Set statusLine: statusline.sh")
else:
    print("    statusLine already configured — skipped")

# ── Write back ───────────────────────────────────────────────────────────────

if changed:
    with open(settings_path, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    print("  settings.json updated successfully")
else:
    print("  settings.json unchanged (all hooks already present)")

PYEOF

# ── Activate default skin immediately ────────────────────────────────────────

echo ""
echo "Activating default skin (nebula)..."
"$DEST/engine/activate.sh" nebula 2>/dev/null || true

# ── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo "Done! Restart Claude Code and run: /skin nebula"
echo ""
