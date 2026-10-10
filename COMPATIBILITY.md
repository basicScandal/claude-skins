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

`engine/play-sound.sh` (bash) and `engine/play-sound.ps1` (Windows) pick a backend for the current machine. Neither blocks the hook on failure. Missing audio is a silent no-op.

| Platform | Backend | Condition | Notes |
|---|---|---|---|
| macOS | `afplay` | Built-in; always available | Plays `/System/Library/Sounds/<Name>.aiff` directly |
| Linux (PulseAudio) | `paplay` | `paplay` in PATH + freedesktop sound theme installed | Looks in `/usr/share/sounds/freedesktop/stereo/` and Ubuntu/GNOME paths |
| Linux (ALSA only) | `aplay` | `aplay` in PATH + `.wav` file found | Fallback when PulseAudio is absent |
| WSL (Windows) | `powershell.exe` | WSL kernel + `powershell.exe` in PATH | Emits a console beep via `[console]::beep()`; no audio driver needed. This row is the bash engine running inside WSL, not native PowerShell |
| Windows (native) | `System.Media.SoundPlayer`, then `System.Media.SystemSounds`, then `[Console]::Beep` | `engine/play-sound.ps1` on Windows PowerShell 5.1 or PowerShell 7 | Plays the closest file in `%SystemRoot%\Media`. A short hidden `pwsh`/`powershell` process calls `PlaySync` so the hook can exit. If no WAV matches, a built-in system sound is used. If that assembly is missing, a short beep is tried. Every failure is ignored |
| Any terminal | ANSI bell (`\a`) | Terminal with bell enabled | Last resort on the bash engine; silent if the terminal bell is disabled |
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

On native Windows, `engine/play-sound.ps1` maps those same macOS names onto WAV files under `%SystemRoot%\Media`. It plays the first file that exists. Tink tries `Windows Notify Messaging.wav`, then `chimes.wav`, then `ding.wav`. Basso tries `Windows Critical Stop.wav`, then `Windows Foreground.wav`, then `chord.wav`. A missing file is not an error.

---

## Native Windows (PowerShell)

`install.ps1`, `uninstall.ps1`, and `engine/*.ps1` target Windows PowerShell 5.1 and PowerShell 7+. They use only built-in commands. The YAML subset in [SCHEMA.md](SCHEMA.md) is parsed in `engine/parse-yaml.ps1`; `powershell-yaml` is not required. `jq` and Python are not required on this path.

Claude Code reads `settings.json`, skill files, and the skin YAML as UTF-8. The installer writes those files **without a BOM**. The `.ps1` sources themselves stay ASCII (Unicode icons are emitted with `[char]` codes) so Windows PowerShell 5.1 does not need a BOM to parse them.

### How Claude Code launches the scripts

Documented behavior from the current hooks and status-line pages:

- Command hooks receive JSON on stdin. On Windows, shell-form commands run in Git Bash when Git Bash is installed, and in PowerShell when it is not. Exec form (`command` plus `args`) spawns the executable directly, with no shell. `install.ps1` writes exec-form hooks that run `cmd.exe /d /c <engine>un-engine.cmd <script>.ps1`. See the [hooks reference](https://code.claude.com/docs/en/hooks).
- `engine/run-engine.cmd` picks the interpreter at run time: `pwsh` on `PATH`, then `powershell` on `PATH`, then `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`. With none of these it exits 0 silently. It passes through stdin, one optional argument, and the exit code. Windows PowerShell 5.1 ships with Windows 10 and 11, so the last tier is almost never reached.
- `statusLine.command` is a single string. It has no `args` field. On Windows it also runs through Git Bash or PowerShell, and backslashes in that string get eaten by Git Bash. `install.ps1` writes `<engine>/run-engine.cmd statusline.ps1` with forward slashes, which both shells can run. If the path contains a space, it writes `powershell -NoProfile -ExecutionPolicy Bypass -File "<path>"` instead. See [Customize your status line](https://code.claude.com/docs/en/statusline).
- The status line script prints one ANSI line. Windows Terminal and the Windows 10+ console render VT sequences when Claude Code displays that line. The script does not call `jq`.

`install.sh` on macOS and Linux still writes the `.sh` commands. It also copies the `.ps1` files into `~/.claude/skins/engine/` so both engines are on disk, but it does not point the hooks at them.

### Terminal colors from a hook

`activate.ps1` writes OSC 10/11/12 (foreground, background, cursor), OSC 4 (palette 0–7), and OSC 0 (window title) to `CONOUT$` on Windows and to `/dev/tty` elsewhere. That matches `activate.sh`.

Claude Code command hooks do not have a controlling terminal, and Windows has no `/dev/tty`. The hook JSON field `terminalSequence` cannot carry palette changes: Claude Code only forwards OSC 0/1/2/9/99/777 and BEL, and it drops OSC palette sequences. See the [hooks reference](https://code.claude.com/docs/en/hooks). Practical result:

- Running `activate.ps1` yourself in Windows Terminal applies the colors when `CONOUT$` opens.
- SessionStart invoked by Claude Code often has nowhere to send those bytes. The banner still goes to hook stdout. The status line does not depend on this and still renders.
- `deactivate.ps1` sends the reset sequences (OSC 110/111/112/104 and a cleared title) the same way, and deletes its temp marker only after a write succeeds.

### Personalities

`activate.ps1` links `personalities/<skin>.md` into `.claude/output-styles/skin-<skin>.md`. Symbolic links on Windows need Developer Mode or an elevated process. When `New-Item -ItemType SymbolicLink` fails, the file is copied instead and the copy path is stored in `engine/personality-manifest.txt`. Deactivate and uninstall remove either kind. `uninstall.sh` removes symlinks and any paths listed in that manifest.

### What the PowerShell engine does not do

- It does not play macOS `.aiff` files or freedesktop `.oga` themes. Those stay on the bash engine.
- It does not require the Windows `powershell-yaml` module, PSReadLine, or any gallery module.
- `git` missing, or a directory that is not a repository, leaves the branch slot empty. The hook still exits 0.
- PowerShell 5.1 was not executed in this repo's Linux test run. The scripts avoid PowerShell 7-only syntax (`&&`, `??`, ternary, `Join-Path` with more than two arguments, `utf8NoBOM` encoding name).
- `/skin` arguments are trimmed. `skin-command-hook.sh` removes one leading space.
- Skin names must match `^[A-Za-z0-9][A-Za-z0-9._-]*$`. That blocks a `../` path from leaving the skins directory.
- `/skin` with no arguments lists skins in sorted order. The bash script uses directory order.

---

## Known Limitations

### Terminal Colors

- **Terminal.app** does not support OSC 4 (ANSI palette). Background and foreground colors apply, but the 8-color ANSI palette (used by `ls`, `git`, `grep` etc.) will not change. The skin will still load; color accuracy is reduced.
- **Alacritty** supports setting colors but does not respond to OSC 10/11 *queries* (i.e., reading back the current color to restore it). `deactivate.sh` / `deactivate.ps1` send the reset sequences anyway; Alacritty may keep the previous palette.
- **Native Windows SessionStart** may not apply OSC palette colors. The hook process often has no console. See [Native Windows](#native-windows-powershell) above. Windows Terminal does honor the sequences when you run `activate.ps1` in a real console.
- **tmux** intercepts OSC sequences by default. Enable passthrough with `set -g allow-passthrough on` in `tmux.conf`, then wrap sequences: `printf '\ePtmux;\e<OSC_SEQ>\a\e\\'`.
- **screen** does not pass through any OSC sequences. Color switching has no effect inside a screen session.
- **SSH sessions** inherit the remote `TERM` value. OSC support depends on the *local* terminal emulator forwarding the sequences, which most modern terminals do when `TERM` is set appropriately.

### Sounds

- **Linux without a sound theme**: `paplay` may be present (PulseAudio running) but no `.oga`/`.wav` files installed. Install `sound-theme-freedesktop` to get audio feedback.
- **Headless / CI environments**: No audio device means all sound backends fail silently. This is intentional — the hook exits 0 and has no side effects.
- **WSL audio**: WSLg (Windows 11, WSL 2.0+) supports full PulseAudio/PipeWire audio. On older WSL 1 or WSL 2 without WSLg, only the PowerShell console beep fallback is available.
- **macOS sandboxed terminals**: If running Claude Code inside a sandboxed context that blocks `/System/Library/Sounds/`, `afplay` will fail silently (the `&>/dev/null` suppresses any error).
- **Volume**: Sound playback respects system volume. Muted system = silent hook, regardless of skin settings.
- **Native Windows WAVs**: `play-sound.ps1` only plays files that exist under `%SystemRoot%\Media`. Names differ slightly across Windows 10 and 11 builds. A missing file falls through to `SystemSounds` and then a beep. There is no way to play the original macOS `.aiff` assets. `System.Media` is a Windows assembly; on PowerShell 7 for Linux the call fails silently, which is what the Linux test run sees.

### General

- Skin activation and color changes apply to the *current terminal window only*. Other open windows retain their previous colors.
- The `TERM` environment variable must support 256 colors or true color for banner gradients to render correctly. Most modern terminals set `TERM=xterm-256color` or `TERM=xterm-kitty` automatically.
