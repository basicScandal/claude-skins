# Claude Skins

Custom skins (visual themes) for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI.

![Claude Skins Demo](https://basicscandal.github.io/claude-skins/demo.gif)

Skins transform the full Claude Code experience — terminal colors, ASCII art banners, themed status lines, Claude's voice/personality, and tool feedback sounds. They don't affect core behavior — just how things look, sound, and feel.

Inspired by [hermes-skins](https://github.com/joeynyc/hermes-skins). Mythos and Netrunner banner art adapted from that project under MIT license.

**[View the gallery](https://basicscandal.github.io/claude-skins/)**

## Quick Start

1. Clone this repo:

```bash
git clone https://github.com/basicScandal/claude-skins.git
```

2. Run the installer:

```bash
cd claude-skins
./install.sh
```

3. Activate a skin:

```bash
# In Claude Code, use the /skin command
/skin nebula

# Or set a permanent default
/skin default
```

That's it. Missing values inherit from the default skin, so you only need to define what you want to change.

### Windows (PowerShell)

Native Windows does not need WSL or Git Bash. From the repo directory, in Windows PowerShell 5.1 or PowerShell 7:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

If `pwsh` is installed, `pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1` works the same way. The installer copies the skins into `$env:USERPROFILE\.claude\skins` and points Claude Code at the `.ps1` engine. Restart Claude Code, then run `/skin nebula`.

`install.sh` remains the macOS and Linux installer. It still wires only the bash hooks, and it also copies the `.ps1` files next to them. On Windows, use `install.ps1`.

## Manual Installation

If you prefer to set things up yourself:

1. Copy `skins/` and `personalities/` to `~/.claude/skins/`
2. Copy `engine/` to `~/.claude/skins/engine/`
3. Make engine scripts executable: `chmod +x ~/.claude/skins/engine/*.sh`
4. Add hooks to your `~/.claude/settings.json` (see [Hooks Setup](#hooks-setup))
5. Create the `/skin` skill (see [Skill Setup](#skill-setup))

On Windows, copy the same directories under `$env:USERPROFILE\.claude\` and skip `chmod`. Hook and status-line commands are in [Hooks Setup](#hooks-setup).

## Available Skins

### Nebula
Offensive security scanner — purple-to-orange gradient, tactical precision.

→ [nebula.yaml](skins/nebula.yaml)

![nebula](https://basicscandal.github.io/claude-skins/nebula.gif)

### Mythos
AGI awakening — Greek mythology meets artificial intelligence. Eye of Providence braille art, blue and gold divine palette.

→ [mythos.yaml](skins/mythos.yaml)

![mythos](https://basicscandal.github.io/claude-skins/mythos.gif)

### Netrunner
Cyberpunk netrunner — neural interface hacker aesthetic. Cyan ICE-breaking colors on black, skull braille art.

→ [netrunner.yaml](skins/netrunner.yaml)

![netrunner](https://basicscandal.github.io/claude-skins/netrunner.gif)

### Noir
1940s detective procedural — high-contrast black and cream, amber accents, hardboiled Chandler narration.

→ [noir.yaml](skins/noir.yaml)

![noir](https://basicscandal.github.io/claude-skins/noir.gif)

### Sensei
Minimalist Japanese ink-wash aesthetic — warm parchment, deep charcoal, vermillion hanko seal accent.

→ [sensei.yaml](skins/sensei.yaml)

![sensei](https://basicscandal.github.io/claude-skins/sensei.gif)

### Mission Control
NASA retro-futurist ops console — amber phosphor on deep navy, Apollo-era mission control aesthetic.

→ [mission-control.yaml](skins/mission-control.yaml)

![mission-control](https://basicscandal.github.io/claude-skins/mission-control.gif)

### Retro86
1980s Commodore 64 nostalgia — classic C64 blue palette, 8-bit ASCII art, enthusiastic magazine voice.

→ [retro86.yaml](skins/retro86.yaml)

![retro86](https://basicscandal.github.io/claude-skins/retro86.gif)

### Brutalist
The anti-skin — pure monochrome, zero decoration, no sounds, maximum terseness.

→ [brutalist.yaml](skins/brutalist.yaml)

![brutalist](https://basicscandal.github.io/claude-skins/brutalist.gif)

### Grimoire
Dark academia spellbook — deep brown parchment, golden arcane sigils, patient wizard's codex voice.

→ [grimoire.yaml](skins/grimoire.yaml)

![grimoire](https://basicscandal.github.io/claude-skins/grimoire.gif)

## What a Skin Changes

| Layer | What it does |
|-------|-------------|
| **Terminal colors** | Background, foreground, cursor, and ANSI palette via OSC sequences |
| **ASCII banner** | Braille art + block letter logo displayed on session start |
| **Status line** | Themed colors, icon, and progress bar in the Claude Code status bar |
| **Personality** | Output style that shapes Claude's voice (oracular, hacker, tactical) |
| **Tool sounds** | macOS system sounds triggered on file writes, commands, errors |

## Commands

```
/skin              List available skins, highlight active one
/skin <name>       Switch to a skin immediately
/skin reset        Deactivate skin, restore terminal defaults
/skin default      Set current skin as permanent default
```

Switching is instant — no restart needed.

## Hooks Setup

Add these to your `~/.claude/settings.json` under `"hooks"`:

**SessionStart** — activate default skin on boot:
```json
{
  "type": "command",
  "command": "~/.claude/skins/engine/activate.sh"
}
```

**SessionEnd** — restore terminal on exit:
```json
{
  "type": "command",
  "command": "~/.claude/skins/engine/deactivate.sh"
}
```

**PostToolUse** — themed sounds (optional):
```json
{
  "matcher": "Bash|Write|Edit|MultiEdit|Grep|Glob",
  "hooks": [{
    "type": "command",
    "command": "~/.claude/skins/engine/skin-tool-hook.sh",
    "timeout": 5
  }]
}
```

**Status line** — replace your current statusline:
```json
"statusLine": {
  "type": "command",
  "command": "~/.claude/skins/engine/statusline.sh"
}
```

### Windows hooks

`install.ps1` writes these for you. Every hook and the status line go through `engine/run-engine.cmd`. Each time it runs, that launcher uses PowerShell 7 (`pwsh`) if it is on `PATH`. Otherwise it uses Windows PowerShell 5.1 (`powershell`), and then the built-in `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`. With no PowerShell at all it exits 0, so a hook never fails. `cmd.exe` cannot run the engine itself; it only starts the launcher. Removing or adding PowerShell 7 after install needs no reinstall.

Hooks use exec form (`command` plus `args`), so no shell parses the path. See the [hooks reference](https://code.claude.com/docs/en/hooks).

**SessionStart:**
```json
{
  "type": "command",
  "command": "C:\\Windows\\system32\\cmd.exe",
  "args": ["/d", "/c", "C:\\Users\\you\\.claude\\skins\\engine\\run-engine.cmd", "activate.ps1"]
}
```

**SessionEnd:** same shape, with `deactivate.ps1`.

**PostToolUse:** same shape, with `skin-tool-hook.ps1`, `"timeout": 5`, and matcher `Bash|PowerShell|Write|Edit|MultiEdit|Grep|Glob`. The `PowerShell` tool is included so command sounds still fire when Claude Code's shell tool is PowerShell rather than Bash. See the [hooks reference](https://code.claude.com/docs/en/hooks).

**Status line:**
```json
"statusLine": {
  "type": "command",
  "command": "C:/Users/you/.claude/skins/engine/run-engine.cmd statusline.ps1"
}
```

The status line is a single command string. [Claude Code runs it through Git Bash or PowerShell](https://code.claude.com/docs/en/statusline), so the path uses forward slashes. If your profile path contains a space, the installer writes `powershell -NoProfile -ExecutionPolicy Bypass -File "C:/.../statusline.ps1"` instead. A quoted `.cmd` path needs `&` in PowerShell but not in bash.

The installer keeps an existing `settings.json.backup`, so a reinstall does not overwrite the backup of your original settings. It also leaves a custom `statusLine` alone, and prints the command to use if you want the skin status line.

## Skill Setup

Create `~/.claude/skills/skin/SKILL.md` — see [engine/SKILL.md](engine/SKILL.md) for the content.

## Creating Your Own Skin

1. Copy [template.yaml](template.yaml) to `skins/<name>.yaml`
2. Customize colors, banner art, branding
3. Optionally add `personalities/<name>.md` for Claude's voice
4. Test: `~/.claude/skins/engine/activate.sh <name>`
   Windows: `pwsh -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skins\engine\activate.ps1" <name>`

See [SCHEMA.md](SCHEMA.md) for the full reference and [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Terminal with OSC sequence support (iTerm2, Kitty, WezTerm, Ghostty, Alacritty, Windows Terminal, Terminal.app)
- macOS / Linux: bash, plus `python3` for the installer and `jq` for the bash status line
- Windows: Windows PowerShell 5.1 or PowerShell 7+. No WSL, Git Bash, Python, or `jq`. `git` is optional and only used for the branch in the status line
- Tool sounds: macOS, Linux (PulseAudio/ALSA), WSL, and native Windows — see [COMPATIBILITY.md](COMPATIBILITY.md)

## Using a Skin? Let Us Know

If you're using claude-skins, we'd love to hear about it! Open a [Discussion](https://github.com/basicScandal/claude-skins/discussions) or tag the repo in your dotfiles.

## License

MIT — see [LICENSE](LICENSE).

Banner art for Mythos and Netrunner adapted from [joeynyc/hermes-skins](https://github.com/joeynyc/hermes-skins) under MIT license.
