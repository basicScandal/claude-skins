# Compatibility

Reference for terminal and platform support in claude-skins.

---

## Terminal Color Support (OSC Sequences)

Claude Skins uses OSC escape sequences to set terminal background, foreground, cursor, and ANSI palette colors dynamically. Support varies by terminal emulator.

| Terminal | OSC 10/11 (fg/bg) | OSC 12 (cursor) | OSC 4 (palette) | Notes |
|---|---|---|---|---|
| iTerm2 | Yes | Yes | Yes | Full support; most reliable on macOS |
| Kitty | Yes | Yes | Yes | Full support; fast GPU renderer |
| WezTerm | Yes | Yes | Yes | Full support; cross-platform |
| Ghostty | Yes | Yes | Yes | Full support; native macOS/Linux |
| Alacritty | Partial | Yes | Yes | OSC 10/11 (bg/fg query) limited; colors apply but may not restore perfectly |
| Windows Terminal | Yes | Yes | Yes | Full support on Windows 10 1903+ |
| GNOME Terminal (VTE) | Yes | Yes | Yes | Supported via VTE 0.52+; some older distro packages lag |
| Terminal.app | Partial | Partial | No | macOS built-in; does not support OSC 4 palette; bg/fg limited |
| tmux (passthrough) | Requires passthrough | Requires passthrough | Requires passthrough | Set `set -g allow-passthrough on`; sequences must be wrapped in DCS passthrough |
| screen | No | No | No | Does not forward OSC sequences |
| xterm | Yes | Yes | Yes | Supported but rarely used for daily work |
| rxvt-unicode (urxvt) | Partial | Yes | Yes | OSC 11 background not always reliable |
| Hyper | Partial | Partial | Partial | Electron-based; behavior depends on xterm.js version |
| VS Code integrated terminal | Yes | Yes | Yes | Supported via xterm.js; restores colors on tab close |

**Key**: "Yes" = works reliably. "Partial" = works with caveats (see Notes). "No" = not implemented.

### OSC Sequence Reference

```
OSC 10 ; color ST    Set default foreground color
OSC 11 ; color ST    Set default background color
OSC 12 ; color ST    Set cursor color
OSC 4 ; n ; color ST Set ANSI palette entry n
```

Where `color` is `rgb:RR/GG/BB` or `#RRGGBB`, and `ST` is `\a` (BEL) or `\033\\` (ST).

---

## Sound Support by Platform

The sound system in `engine/play-sound.sh` detects the runtime platform and uses the best available backend. It never blocks and never errors — missing sound support is a silent no-op.

| Platform | Backend | Condition | Notes |
|---|---|---|---|
| macOS | `afplay` | Built-in; always available | Plays `/System/Library/Sounds/<Name>.aiff` directly |
| Linux (PulseAudio) | `paplay` | `paplay` in PATH + freedesktop sound theme installed | Looks in `/usr/share/sounds/freedesktop/stereo/` and Ubuntu/GNOME paths |
| Linux (ALSA only) | `aplay` | `aplay` in PATH + `.wav` file found | Fallback when PulseAudio is absent |
| WSL (Windows) | `powershell.exe` | WSL kernel + `powershell.exe` in PATH | Emits a console beep via `[console]::beep()`; no audio driver needed |
| Any terminal | ANSI bell (`\a`) | Terminal with bell enabled | Last resort; silent if terminal bell is disabled |
| No sound system | (nothing) | None of the above available | Silent no-op; hook exits cleanly |

### Installing freedesktop Sounds on Linux

The most common source of themed sounds is the `sound-theme-freedesktop` package:

```bash
# Debian / Ubuntu
sudo apt install sound-theme-freedesktop

# Fedora / RHEL
sudo dnf install sound-theme-freedesktop

# Arch
sudo pacman -S sound-theme-freedesktop
```

Files are installed to `/usr/share/sounds/freedesktop/stereo/` as `.oga` files. PulseAudio (`paplay`) reads them directly.

### macOS Sound Name Mapping

Skin YAML files use macOS sound names (e.g. `Tink`, `Pop`, `Basso`). On Linux, these are mapped to the nearest freedesktop event sound:

| macOS Name | Linux Event Sound |
|---|---|
| Basso | `dialog-error` |
| Blow | `dialog-warning` |
| Bottle, Frog, Morse, Submarine | `message` |
| Funk | `dialog-warning` |
| Glass, Hero, Purr | `complete` |
| Ping, Pop, Tink | `bell` |
| Sosumi | `dialog-error` |

---

## Known Limitations

### Terminal Colors

- **Terminal.app** does not support OSC 4 (ANSI palette). Background and foreground colors apply, but the 8-color ANSI palette (used by `ls`, `git`, `grep` etc.) will not change. The skin will still load; color accuracy is reduced.
- **Alacritty** supports setting colors but does not respond to OSC 10/11 *queries* (i.e., reading back the current color to restore it). The `deactivate.sh` script may not fully restore the original palette on Alacritty.
- **tmux** intercepts OSC sequences by default. Enable passthrough with `set -g allow-passthrough on` in `tmux.conf`, then wrap sequences: `printf '\ePtmux;\e<OSC_SEQ>\a\e\\'`.
- **screen** does not pass through any OSC sequences. Color switching has no effect inside a screen session.
- **SSH sessions** inherit the remote `TERM` value. OSC support depends on the *local* terminal emulator forwarding the sequences, which most modern terminals do when `TERM` is set appropriately.

### Sounds

- **Linux without a sound theme**: `paplay` may be present (PulseAudio running) but no `.oga`/`.wav` files installed. Install `sound-theme-freedesktop` to get audio feedback.
- **Headless / CI environments**: No audio device means all sound backends fail silently. This is intentional — the hook exits 0 and has no side effects.
- **WSL audio**: WSLg (Windows 11, WSL 2.0+) supports full PulseAudio/PipeWire audio. On older WSL 1 or WSL 2 without WSLg, only the PowerShell console beep fallback is available.
- **macOS sandboxed terminals**: If running Claude Code inside a sandboxed context that blocks `/System/Library/Sounds/`, `afplay` will fail silently (the `&>/dev/null` suppresses any error).
- **Volume**: Sound playback respects system volume. Muted system = silent hook, regardless of skin settings.

### General

- Skin activation and color changes apply to the *current terminal window only*. Other open windows retain their previous colors.
- The `TERM` environment variable must support 256 colors or true color for banner gradients to render correctly. Most modern terminals set `TERM=xterm-256color` or `TERM=xterm-kitty` automatically.
