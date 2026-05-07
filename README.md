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

## Manual Installation

If you prefer to set things up yourself:

1. Copy `skins/` and `personalities/` to `~/.claude/skins/`
2. Copy `engine/` to `~/.claude/skins/engine/`
3. Make engine scripts executable: `chmod +x ~/.claude/skins/engine/*.sh`
4. Add hooks to your `~/.claude/settings.json` (see [Hooks Setup](#hooks-setup))
5. Create the `/skin` skill (see [Skill Setup](#skill-setup))

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

## Skill Setup

Create `~/.claude/skills/skin/SKILL.md` — see [engine/SKILL.md](engine/SKILL.md) for the content.

## Creating Your Own Skin

1. Copy [template.yaml](template.yaml) to `skins/<name>.yaml`
2. Customize colors, banner art, branding
3. Optionally add `personalities/<name>.md` for Claude's voice
4. Test: `~/.claude/skins/engine/activate.sh <name>`

See [SCHEMA.md](SCHEMA.md) for the full reference and [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Python 3 with PyYAML (`pip install pyyaml`)
- Terminal with OSC sequence support (iTerm2, Kitty, WezTerm, Ghostty, Terminal.app)
- macOS for tool sounds (silently skipped on Linux)

## License

MIT — see [LICENSE](LICENSE).

Banner art for Mythos and Netrunner adapted from [joeynyc/hermes-skins](https://github.com/joeynyc/hermes-skins) under MIT license.
