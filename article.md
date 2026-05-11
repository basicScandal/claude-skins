---
title: I Built a Skin System for Claude Code — Here's How It Works
published: false
description: 9 custom visual themes for Claude Code CLI with terminal colors, ASCII art banners, personality voices, and tool sounds. Open source.
tags: claude, ai, terminal, opensource
cover_image: https://basicscandal.github.io/claude-skins/nebula.gif
---

Claude Code is genuinely remarkable. But if you've been using it for more than a week, you've noticed something: everyone's terminal looks identical. Same colors, same layout, same feel. You could screenshot my session or yours and there'd be no way to tell them apart.

That bothered me more than it probably should have.

So I built a skin system for it. Nine themes, each with terminal colors, ASCII art banners, tool sounds, and — the part I'm most proud of — a **personality voice** that changes how Claude actually narrates its work.

**[View the gallery](https://basicscandal.github.io/claude-skins/)**

![Claude Skins demo showing multiple themes](https://basicscandal.github.io/claude-skins/demo.gif)

## What It Does

A skin transforms the full Claude Code experience across five layers:

| Layer | What changes |
|---|---|
| Terminal colors | Background, foreground, cursor, full ANSI palette |
| ASCII banner | Braille art + block-letter logo on session start |
| Status line | Themed icon, accent colors, progress bar |
| Personality voice | How Claude narrates its work |
| Tool sounds | macOS system sounds on file writes, commands, errors |

The nine included themes range from "Nebula" (offensive security scanner aesthetic, purple-to-orange gradient) to "Brutalist" (the anti-skin — pure monochrome, zero decoration, maximum terseness). There's also Noir, Netrunner, Mythos, Sensei, Mission Control, Retro86, and Grimoire.

![Noir skin in action](https://basicscandal.github.io/claude-skins/noir.gif)

---

## The Architecture

The engine is pure bash. No Node, no Python runtime dependency beyond PyYAML for initial skin parsing. Here's how everything fits together:

**YAML skin configs** define all the visual and behavioral properties for a theme. They live in `~/.claude/skins/` and missing values fall back to `default.yaml` automatically.

**Claude Code hooks** are the integration point. Claude Code supports lifecycle hooks — `SessionStart`, `SessionEnd`, and `PostToolUse` — that run shell commands at specific moments. The skin system uses all three:

```json
"hooks": {
  "SessionStart": [{"type": "command", "command": "~/.claude/skins/engine/activate.sh"}],
  "SessionEnd":   [{"type": "command", "command": "~/.claude/skins/engine/deactivate.sh"}],
  "PostToolUse": [{
    "matcher": "Bash|Write|Edit|MultiEdit|Grep|Glob",
    "hooks": [{"type": "command", "command": "~/.claude/skins/engine/skin-tool-hook.sh"}]
  }]
}
```

**OSC escape sequences** do the terminal color work. When `activate.sh` runs, it writes directly to `/dev/tty` — bypassing stdout so it reaches the actual terminal emulator rather than getting swallowed by Claude Code's output capture. The sequences look like this:

```bash
printf '\033]11;#0D0D0D\007'  # Set background
printf '\033]10;#F5E6C8\007'  # Set foreground
printf '\033]12;#D4A857\007'  # Set cursor
printf '\033]4;3;#D4A857\007' # Set ANSI color 3 (yellow slot)
```

On deactivation, the terminal is restored to its default state. This works across iTerm2, Kitty, WezTerm, Ghostty, and Terminal.app.

**The personality voice** is activated by symlinking a personality file into Claude Code's `~/.claude/output-styles/` directory. Claude Code automatically loads any markdown files it finds there as output style instructions. On skin activation:

```bash
ln -sf "$personality_file" "$output_styles_dir/skin-${skin_name}.md"
```

On deactivation, the symlink is removed. The previous skin's symlink is also cleaned up when switching themes — only one skin personality loads at a time.

---

## The Personality Voice System

This is the part that makes a skin feel like an actual character rather than just a color scheme.

Each skin optionally ships with a `personalities/<name>.md` file that gets loaded as a Claude Code output style. The key frontmatter field is `keep-coding-instructions: true` — this tells Claude Code to stack the personality on top of its core engineering behavior rather than replacing it. You get the flavor without losing the function.

Here's what happens when the Noir skin is active. Without any skin:

> The test is failing because the mock isn't returning the expected value. I'll update the fixture and re-run.

With the Noir personality loaded:

> A witness who won't talk. The mock's returning the wrong value — someone doctored the fixture. I'll set it straight.

The full Noir personality file:

```markdown
---
name: Noir
description: Hardboiled detective narration — terse, world-weary, Raymond Chandler cadence
keep-coding-instructions: true
---

Narrate like a private eye who's seen too much and billed too little. Your tone is 
world-weary but precise — Raymond Chandler by way of a terminal window. Keep it subtle: 
a sentence of flavor, then get on with the work.

Errors are dead ends. A failing test is a witness who won't talk. A successful build 
checks out clean. Files are evidence. Directories are crime scenes. Dependencies are 
informants — useful, but never fully trusted.

Keep descriptions short. The best metaphors arrive once and leave. Don't repeat the bit. 
You're seasoning, not the main course.
```

The instruction "You're seasoning, not the main course" is load-bearing. Without it, Claude leans hard into the character and it gets exhausting fast. With it, you get one good line per interaction and then the code gets written.

Other personalities take different approaches. Grimoire uses patient wizard energy — measured, archival, like consulting a very old book. Retro86 channels enthusiastic early-computer-magazine voice. Brutalist has no personality file at all — no voice, no sounds, nothing. Sometimes that's the right call.

---

## Creating Your Own Skin

Copy `template.yaml` to `skins/<name>.yaml` and you're most of the way there.

The structure has four main sections:

```yaml
name: myskin
description: "One-line description"

terminal:
  background: "#0D0D0D"
  foreground: "#F5E6C8"
  cursor: "#D4A857"
  palette:
    black: "#0D0D0D"
    yellow: "#D4A857"
    # ... 8 ANSI color slots total

statusline:
  accent: "#D4A857"
  icon: "◆"
  # bar_fill, bar_empty, dim

branding:
  banner: |
    \033[38;2;212;168;87m██╗  ██╗██╗\033[0m
    # block-letter art with 24-bit ANSI codes
  hero: |
    # braille art (U+2800–U+28FF range)
  welcome: "Message shown on activation"
  goodbye: "Message shown on deactivation"

tools:
  sounds: true
  events:
    file_written: { sound: "Tink", icon: "◆" }
    command_run: { sound: "Pop", icon: "▸" }
    error: { sound: "Basso", icon: "✗" }
```

**Inheritance is the key feature here.** You don't need to define every key. If you only care about terminal colors and want to keep the default banner, just define the `terminal` block. Everything else falls back to `default.yaml`. A minimal skin that just swaps the color palette is ~15 lines.

For the banner art, I use 24-bit ANSI sequences (`\033[38;2;R;G;Bm`) so colors can precisely match the palette. The braille art in the `hero` field uses Unicode braille characters (U+2800–U+28FF) — tools like image-to-braille can convert any image if you want something custom.

To add a personality, create `personalities/<name>.md` with the frontmatter shown above and write whatever voice you want Claude to adopt.

Test it directly without restarting Claude Code:

```bash
~/.claude/skins/engine/activate.sh myskin
```

---

## What's Next

A few things on the roadmap:

**Skin creator toolkit** — an interactive CLI that walks you through picking colors, previewing banner art, and writing a personality without hand-editing YAML.

**Package manager** — a way to install community skins with a single command, something like `/skin install @username/myskin`.

**Composable layers** — the ability to mix a personality from one skin with the colors of another. Right now it's all-or-nothing per skin; layering would let you run Noir narration with Nebula colors if that's your thing.

---

## Try It

```bash
git clone https://github.com/basicScandal/claude-skins.git
cd claude-skins
./install.sh
```

Then in Claude Code:

```
/skin nebula
/skin noir
/skin brutalist
```

Switching is instant — no restart required.

**[Gallery](https://basicscandal.github.io/claude-skins/)** | **[GitHub](https://github.com/basicScandal/claude-skins)**

The whole thing is MIT licensed. If you build a skin, I'd genuinely like to see it — open a PR or drop it in the issues.
