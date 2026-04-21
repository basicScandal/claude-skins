#!/usr/bin/env python3
"""Generate screenshot PNGs for each Claude skin using Rich console export."""

import os
import re
import subprocess
import yaml
from rich.console import Console
from rich.text import Text
from rich.panel import Panel
from rich.style import Style

SKINS_DIR = os.path.join(os.path.dirname(__file__), "skins")
SCREENSHOTS_DIR = os.path.join(os.path.dirname(__file__), "screenshots")
STATUS_TEST = '{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/Users/demo/project"},"context_window":{"used_percentage":42.5},"cost":{"total_cost_usd":1.23,"total_lines_added":150,"total_lines_removed":30}}'


def ansi_to_rich_text(ansi_str: str) -> Text:
    """Convert ANSI escape-coded string to Rich Text object."""
    text = Text()
    # Pattern matches: \033[...m or \033]...;\007 sequences
    parts = re.split(r'(\033\[[0-9;]*m)', ansi_str)

    current_style = Style()
    for part in parts:
        if not part:
            continue
        m = re.match(r'\033\[([0-9;]*)m', part)
        if m:
            codes = m.group(1)
            if codes == '0' or codes == '':
                current_style = Style()
            elif codes == '2':
                current_style = Style(dim=True)
            elif codes.startswith('38;2;'):
                rgb = codes[5:].split(';')
                if len(rgb) == 3:
                    r, g, b = int(rgb[0]), int(rgb[1]), int(rgb[2])
                    current_style = Style(color=f"rgb({r},{g},{b})")
            elif codes.startswith('2;38;2;'):
                rgb = codes[7:].split(';')
                if len(rgb) == 3:
                    r, g, b = int(rgb[0]), int(rgb[1]), int(rgb[2])
                    current_style = Style(color=f"rgb({r},{g},{b})", dim=True)
            elif codes == '31':
                current_style = Style(color="red")
            elif codes == '32':
                current_style = Style(color="green")
            elif codes == '33':
                current_style = Style(color="yellow")
        else:
            text.append(part, style=current_style)
    return text


def generate_screenshot(skin_name: str):
    """Generate an SVG screenshot for a skin."""
    skin_path = os.path.join(SKINS_DIR, f"{skin_name}.yaml")
    with open(skin_path) as f:
        skin = yaml.safe_load(f)

    bg = skin.get("terminal", {}).get("background", "#1a1a2e")
    fg = skin.get("terminal", {}).get("foreground", "#e0e0e0")
    branding = skin.get("branding", {})
    statusline = skin.get("statusline", {})

    # Convert \033 literals from YAML to actual escape characters
    for key in ("banner", "hero", "welcome", "goodbye"):
        val = branding.get(key, "")
        if val:
            branding[key] = val.replace("\\033", "\033")

    # Build the console output
    console = Console(
        record=True,
        width=72,
        force_terminal=True,
        color_system="truecolor",
    )

    # Render hero art
    hero = branding.get("hero", "")
    if hero:
        for line in hero.strip().split("\n"):
            line = line.strip()
            if line:
                rich_line = ansi_to_rich_text(line)
                console.print(rich_line)
        console.print()

    # Render banner
    banner = branding.get("banner", "")
    if banner:
        for line in banner.strip().split("\n"):
            line = line.strip()
            if line:
                rich_line = ansi_to_rich_text(line)
                console.print(rich_line)
        console.print()

    # Welcome message
    welcome = branding.get("welcome", "")
    if welcome:
        console.print(f"[dim]{welcome}[/dim]")
        console.print()

    # Fake status line
    icon = statusline.get("icon", ">")
    accent = statusline.get("accent", "#FFBF00")
    dim_color = statusline.get("dim", "#666666")
    bar_fill = statusline.get("bar_fill", "#FFBF00")
    bar_empty = statusline.get("bar_empty", "#333333")

    bar = ""
    for i in range(4):
        bar += f"[{bar_fill}]▓[/{bar_fill}]"
    for i in range(6):
        bar += f"[{bar_empty}]░[/{bar_empty}]"

    status = Text()
    status_str = f"[{accent}]{icon} Opus 4.6[/{accent}] [{dim_color}]|[/{dim_color}] project [{dim_color}]|[/{dim_color}] [{dim_color}]⎇[/{dim_color}] main* [{dim_color}]|[/{dim_color}] {bar} [green]42%[/green] [{dim_color}]|[/{dim_color}] $1.23 [{dim_color}]|[/{dim_color}] [green]+150[/green] [red]-30[/red]"
    console.print()
    console.print(f"[{dim_color}]{'─' * 70}[/{dim_color}]")
    console.print(status_str)

    # Export as SVG
    svg = console.export_svg(
        title=f"Claude Code — {skin_name}",
        theme=None,
    )

    # Custom background color in SVG
    svg = svg.replace(
        'class="rich-terminal"',
        f'class="rich-terminal" style="background-color: {bg};"'
    )
    # Fix the terminal background in the SVG rect
    svg = re.sub(
        r'(<rect[^>]*class="terminal-[^"]*-body"[^>]*fill=")[^"]*(")',
        f'\\1{bg}\\2',
        svg
    )

    svg_path = os.path.join(SCREENSHOTS_DIR, f"{skin_name}.svg")
    with open(svg_path, "w") as f:
        f.write(svg)

    print(f"  Generated {svg_path}")

    # Convert SVG to PNG if possible
    try:
        from cairosvg import svg2png
        png_path = os.path.join(SCREENSHOTS_DIR, f"{skin_name}.png")
        svg2png(bytestring=svg.encode(), write_to=png_path, scale=2)
        print(f"  Generated {png_path}")
    except ImportError:
        pass


if __name__ == "__main__":
    os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

    for skin_file in sorted(os.listdir(SKINS_DIR)):
        if skin_file == "default.yaml":
            continue
        if not skin_file.endswith(".yaml"):
            continue
        skin_name = skin_file.replace(".yaml", "")
        print(f"Generating screenshot for {skin_name}...")
        generate_screenshot(skin_name)

    print("\nDone! SVGs saved to screenshots/")
