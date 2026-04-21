---
name: skin
description: Switch Claude Code visual themes (skins). List available skins, activate a skin, reset to defaults, or set a permanent default. USE WHEN user says '/skin', 'change skin', 'switch theme', 'activate skin', or wants to change Claude's visual appearance.
---

# Skin — Claude Code Visual Themes

Switch between visual skins that change terminal colors, ASCII banners, status line theme, Claude's personality/voice, and tool feedback sounds.

## Usage

The user invokes this skill with `/skin` followed by an optional argument.

## Behavior

### `/skin` (no arguments) — List available skins

Run the following to list skins and show which is active:

```bash
~/.claude/skins/engine/skin-command-hook.sh <<< '{"prompt": "/skin"}'
```

Display the output to the user.

### `/skin <name>` — Activate a skin

Run activate.sh with the skin name:

```bash
~/.claude/skins/engine/activate.sh <name>
```

After activation, tell the user the skin is active and mention they can set it as default with `/skin default`.

If the personality file exists at `~/.claude/skins/personalities/<name>.md`, read it and adopt that voice for the rest of the session.

### `/skin reset` — Deactivate and restore

Run deactivate.sh:

```bash
~/.claude/skins/engine/deactivate.sh
```

Tell the user the terminal has been restored.

### `/skin default` — Set current as permanent default

Read the current skin from `~/.claude/skins/engine/current`, then update `~/.claude/skins/engine/config.yaml` to set `default_skin` to that value.

Tell the user which skin was set as default.
