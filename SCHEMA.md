# Claude Skins Schema

Complete reference for all configurable skin keys.

## Top-Level Structure

```yaml
name: myskin                    # Required. Must match filename.
description: Short description  # Optional but recommended.

terminal: { ... }      # Terminal color configuration
statusline: { ... }    # Status line theme tokens
branding: { ... }      # Banner art, welcome/goodbye messages, prompt prefix
personality:
  voice: "..."         # System prompt fragment for Claude's voice
tools: { ... }         # Tool feedback sounds and icons
```

## Terminal (8 keys)

Controls terminal colors via OSC escape sequences. Applied to the actual terminal emulator on skin activation, restored on deactivation.

| Key | What it sets | Example |
|-----|-------------|---------|
| `background` | Terminal background color | `#0E0520` |
| `foreground` | Terminal text color | `#E0D6F0` |
| `cursor` | Cursor color | `#FF6B35` |
| `palette.black` | ANSI color 0 | `#0E0520` |
| `palette.red` | ANSI color 1 | `#FF3D3D` |
| `palette.green` | ANSI color 2 | `#39FF14` |
| `palette.yellow` | ANSI color 3 | `#FF6B35` |
| `palette.blue` | ANSI color 4 | `#8A2BE2` |
| `palette.magenta` | ANSI color 5 | `#6A0DAD` |
| `palette.cyan` | ANSI color 6 | `#B388FF` |
| `palette.white` | ANSI color 7 | `#E0D6F0` |

## Status Line (5 keys)

Color tokens consumed by the shared `statusline.sh` script.

| Key | What it colors | Example |
|-----|----------------|---------|
| `accent` | Model name, active elements | `#FF6B35` |
| `dim` | Separators, secondary text | `#6A0DAD` |
| `bar_fill` | Filled portion of context bar | `#FF6B35` |
| `bar_empty` | Empty portion of context bar | `#1A0830` |
| `icon` | Skin indicator icon in status line | `✦` |

## Branding (6 keys)

| Key | Type | Description |
|-----|------|-------------|
| `banner` | string | Block-letter ASCII art logo with ANSI escape codes |
| `hero` | string | Braille art displayed above the banner |
| `welcome` | string | Message shown after banner on activation |
| `goodbye` | string | Message shown on deactivation |
| `prompt_prefix` | string | Thematic prefix character |

### ANSI Color Codes in Banners

Use 24-bit ANSI escape sequences for banner colors:

```
\033[38;2;R;G;Bm   Set foreground to RGB
\033[0m             Reset all formatting
\033[2m             Dim text
```

Each line of banner/hero art should end with `\033[0m` to reset.

### Braille Art

Braille characters (U+2800–U+28FF) work well for detailed artwork. Use `⠀` (U+2800, blank braille) for spacing. Tools like [image-to-braille](https://github.com/505e06b2/Image-to-Braille) can convert images.

## Personality (1 key)

| Key | Type | Description |
|-----|------|-------------|
| `voice` | string | System prompt fragment defining Claude's tone and style |

The voice is saved as a Claude Code output style file in `personalities/<name>.md` with frontmatter:

```markdown
---
name: Skin Name
description: One-line description
keep-coding-instructions: true
---

Voice instructions here...
```

Set `keep-coding-instructions: true` so Claude retains its core software engineering behavior.

## Tools (4 keys)

| Key | Type | Description |
|-----|------|-------------|
| `sounds` | boolean | Enable/disable macOS system sounds |
| `prefix` | string | Character prefixed to tool output lines |
| `events` | dict | Per-event sound and icon configuration |

### Events

```yaml
tools:
  events:
    file_written: { sound: "Tink", icon: "◆" }
    command_run: { sound: "Pop", icon: "✦" }
    error: { sound: "Basso", icon: "⚠" }
    search: { sound: "Pop", icon: "◈" }
```

Available macOS sounds: `Basso`, `Blow`, `Bottle`, `Frog`, `Funk`, `Glass`, `Hero`, `Morse`, `Ping`, `Pop`, `Purr`, `Sosumi`, `Submarine`, `Tink`.

Tool name mapping:

| Claude Code Tool | Event |
|-----------------|-------|
| `Write`, `Edit`, `MultiEdit` | `file_written` |
| `Bash` | `command_run` |
| `Grep`, `Glob` | `search` |
| (any failure) | `error` |

## Inheritance

Missing values inherit from `default.yaml`. You only need to define what you want to change.

## Full Template

See [template.yaml](template.yaml) for a copy-paste starting point with all keys.
