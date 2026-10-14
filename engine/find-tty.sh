#!/bin/bash
# Claude Skins — locate the terminal that OSC escape sequences should go to
#
# Hooks and tool calls run without a controlling terminal, so /dev/tty
# can't be opened there. On Windows (Git Bash / MSYS2) we walk the Windows
# parent-process chain up to the first process MSYS knows to own a pty
# (e.g. claude.exe launched from a mintty shell) and use that pty instead.
#
# Usage (after sourcing):
#   find_skin_tty   — prints the device path, or nothing if none is reachable

find_skin_tty() {
  if { : > /dev/tty; } 2>/dev/null; then
    echo /dev/tty
    return 0
  fi

  # Fallback below is MSYS2 / Git Bash only
  [[ -r "/proc/$$/winpid" ]] || return 0
  command -v powershell.exe >/dev/null 2>&1 || return 0

  # Map Windows PID -> pty for every MSYS process that has one
  local -A tty_by_winpid=()
  local d ctty wp
  for d in /proc/[0-9]*; do
    ctty=$(cat "$d/ctty" 2>/dev/null) || continue
    [[ "$ctty" == /dev/* ]] || continue
    wp=$(cat "$d/winpid" 2>/dev/null) || continue
    [[ -n "$wp" ]] && tty_by_winpid[$wp]="$ctty"
  done
  [[ ${#tty_by_winpid[@]} -gt 0 ]] || return 0

  # Windows ancestors of this process, nearest first (one PowerShell call)
  local winpid ancestors
  winpid=$(< "/proc/$$/winpid")
  ancestors=$(powershell.exe -NoProfile -NonInteractive -Command \
    '$pp=@{}; Get-CimInstance Win32_Process -Property ProcessId,ParentProcessId | ForEach-Object { $pp[[int]$_.ProcessId]=[int]$_.ParentProcessId }; $p='"$winpid"'; for ($i=0; $i -lt 16 -and $pp.ContainsKey($p); $i++) { $p=$pp[$p]; $p }' \
    2>/dev/null | tr -d '\r') || return 0

  local pid
  for pid in $ancestors; do
    ctty="${tty_by_winpid[$pid]:-}"
    if [[ -n "$ctty" ]] && { : > "$ctty"; } 2>/dev/null; then
      echo "$ctty"
      return 0
    fi
  done
  return 0
}
