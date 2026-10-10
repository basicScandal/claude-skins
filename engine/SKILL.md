---
name: skin
description: Switch Claude Code visual themes (skins). List available skins, activate a skin, reset to defaults, or set a permanent default. USE WHEN user says '/skin', 'change skin', 'switch theme', 'activate skin', or wants to change Claude's visual appearance.
---

# Skin — Claude Code Visual Themes

Switch between visual skins that change terminal colors, ASCII banners, status line theme, Claude's personality/voice, and tool feedback sounds.

## Usage

The user invokes this skill with `/skin` followed by an optional argument.

## Which script to run

The engine is installed twice, once per shell. Pick the one that matches the user's machine.

| Platform | How to run a script |
| --- | --- |
| macOS, Linux, WSL, Git Bash | `~/.claude/skins/engine/<name>.sh` |
| Windows PowerShell (no WSL / Git Bash required) | `pwsh` if it is on `PATH`, otherwise `powershell`: `pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skins\engine\<name>.ps1"` |

Do not run the `.sh` files on native Windows. Do not run the `.ps1` files from bash on macOS or Linux.

Windows examples below use `pwsh`. If `Get-Command pwsh` fails, substitute `powershell`.

## Behavior

### `/skin` (no arguments) — List available skins

macOS / Linux:

```bash
~/.claude/skins/engine/skin-command-hook.sh <<< '{"prompt": "/skin"}'
```

Windows:

```powershell
'{"prompt": "/skin"}' | pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skins\engine\skin-command-hook.ps1"
```

Display the script's stdout. The script exits 2 so that, when it is also wired as a hook, Claude Code does not send the `/skin` prompt to the model. Still show the list to the user.

### `/skin <name>` — Activate a skin

macOS / Linux:

```bash
~/.claude/skins/engine/activate.sh <name>
```

Windows:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skins\engine\activate.ps1" <name>
```

After activation, tell the user the skin is active and mention they can set it as default with `/skin default`.

If the personality file exists, read it and adopt that voice for the rest of the session.

- macOS / Linux: `~/.claude/skins/personalities/<name>.md`
- Windows: `$env:USERPROFILE\.claude\skins\personalities\<name>.md`

### `/skin reset` — Deactivate and restore

macOS / Linux:

```bash
~/.claude/skins/engine/deactivate.sh
```

Windows:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skins\engine\deactivate.ps1"
```

Tell the user the terminal has been restored.

### `/skin default` — Set current as permanent default

Read the current skin, then set `default_skin` in the engine config to that value.

- macOS / Linux: `~/.claude/skins/engine/current` and `~/.claude/skins/engine/config.yaml`
- Windows: `$env:USERPROFILE\.claude\skins\engine\current` and `$env:USERPROFILE\.claude\skins\engine\config.yaml`

`config.yaml` is a single `default_skin:` line unless the user has added more. Replace that line; do not rewrite the rest of the file.

Tell the user which skin was set as default.
