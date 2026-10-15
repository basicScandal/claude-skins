#!/bin/bash
# Claude Skins — locate a writable terminal device
# Claude Code runs hooks (and Bash tool commands) without a controlling
# terminal, so /dev/tty fails with "device not configured". Fall back to
# the tty of the nearest ancestor process that has one (claude itself).

find_tty() {
  if ( : > /dev/tty ) 2>/dev/null; then
    echo /dev/tty
    return 0
  fi

  local pid=$$ t
  while [[ -n "$pid" && "$pid" -gt 1 ]]; do
    t=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
    if [[ -n "$t" && "$t" != "??" && "$t" != "?" ]]; then
      [[ "$t" == /dev/* ]] || t="/dev/$t"
      if [[ -w "$t" ]]; then
        echo "$t"
        return 0
      fi
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
  return 1
}
