#!/bin/bash
# Claude Skins — uninstaller
# Removes skins files, the /skin skill, and cleans hooks from settings.json.

set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
BACKUP="${SETTINGS}.backup"

echo "Uninstalling Claude Skins..."

# ── Option: restore from backup ──────────────────────────────────────────────

if [[ -f "$BACKUP" ]]; then
  echo ""
  read -rp "Backup found at settings.json.backup — restore it? [y/N] " yn
  case "$yn" in
    [Yy]*)
      cp "$BACKUP" "$SETTINGS"
      echo "  Restored settings.json from backup"
      SKIP_JSON_PATCH=1
      ;;
    *)
      SKIP_JSON_PATCH=0
      ;;
  esac
else
  SKIP_JSON_PATCH=0
fi

# ── Remove hooks from settings.json (if not restoring from backup) ───────────

if [[ "$SKIP_JSON_PATCH" -eq 0 && -f "$SETTINGS" ]]; then
  python3 << 'PYEOF'
import json, os

settings_path = os.path.expanduser("~/.claude/settings.json")

with open(settings_path) as f:
    cfg = json.load(f)

SKIN_FRAGMENTS = [
    "skins/engine/activate.sh",
    "skins/engine/deactivate.sh",
    "skins/engine/skin-tool-hook.sh",
]

changed = False

# Remove skin hooks from each event
for event, entries in list(cfg.get("hooks", {}).items()):
    new_entries = []
    for entry in entries:
        new_hooks = [
            h for h in entry.get("hooks", [])
            if not any(frag in h.get("command", "") for frag in SKIN_FRAGMENTS)
        ]
        if len(new_hooks) != len(entry.get("hooks", [])):
            changed = True
        if new_hooks:
            entry = dict(entry)
            entry["hooks"] = new_hooks
            new_entries.append(entry)
        else:
            changed = True  # whole entry removed
    cfg["hooks"][event] = new_entries

# Remove statusLine if it points to skins
sl = cfg.get("statusLine", {})
if isinstance(sl, dict) and "skins/engine/statusline.sh" in sl.get("command", ""):
    del cfg["statusLine"]
    changed = True
    print("  Removed statusLine configuration")

if changed:
    with open(settings_path, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    print("  Removed skin hooks from settings.json")
else:
    print("  No skin hooks found in settings.json — nothing to remove")

PYEOF
fi

# ── Remove skins directory ───────────────────────────────────────────────────

if [[ -d "$HOME/.claude/skins" ]]; then
  rm -rf "$HOME/.claude/skins"
  echo "  Removed ~/.claude/skins/"
else
  echo "  ~/.claude/skins/ not found — skipped"
fi

# ── Remove /skin skill ───────────────────────────────────────────────────────

if [[ -d "$HOME/.claude/skills/skin" ]]; then
  rm -rf "$HOME/.claude/skills/skin"
  echo "  Removed ~/.claude/skills/skin/"
else
  echo "  ~/.claude/skills/skin/ not found — skipped"
fi

# ── Remove backup ────────────────────────────────────────────────────────────

if [[ -f "$BACKUP" ]]; then
  rm -f "$BACKUP"
  echo "  Removed settings.json.backup"
fi

echo ""
echo "Claude Skins uninstalled. Restart Claude Code to complete removal."
echo ""
