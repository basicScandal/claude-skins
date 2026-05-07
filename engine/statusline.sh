#!/bin/bash
# Claude Skins — themed status line
# Drop-in replacement for ~/.claude/statusline.sh
# Reads active skin colors, falls back to defaults

input=$(cat)

ENGINE_DIR="$HOME/.claude/skins/engine"
SKINS_DIR="$HOME/.claude/skins"

# Extract fields
MODEL=$(echo "$input" | jq -r '.model.display_name // "..."')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // "~"' | xargs basename)
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Git branch (cached for 5s)
CACHE="/tmp/claude-statusline-git-cache"
CACHE_AGE=999
if [ -f "$CACHE" ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    CACHE_AGE=$(( $(date +%s) - $(stat -f %m "$CACHE") ))
  else
    CACHE_AGE=$(( $(date +%s) - $(stat -c %Y "$CACHE") ))
  fi
fi

if [ "$CACHE_AGE" -gt 5 ]; then
  BRANCH=$(git -C "$(echo "$input" | jq -r '.workspace.current_dir // "."')" branch --show-current 2>/dev/null || echo "")
  DIRTY=$(git -C "$(echo "$input" | jq -r '.workspace.current_dir // "."')" status --porcelain 2>/dev/null | head -1)
  if [ -n "$DIRTY" ]; then
    GIT_INFO="${BRANCH}*"
  else
    GIT_INFO="${BRANCH}"
  fi
  echo "$GIT_INFO" > "$CACHE"
else
  GIT_INFO=$(cat "$CACHE")
fi

# --- Load skin colors ---
SKIN_NAME="default"
if [[ -f "$ENGINE_DIR/current" ]]; then
  SKIN_NAME=$(cat "$ENGINE_DIR/current" 2>/dev/null || echo "default")
fi

# Defaults
ACCENT_HEX="FFBF00"
DIM_HEX="666666"
BAR_FILL_HEX="FFBF00"
BAR_EMPTY_HEX="333333"
ICON=">"

SKIN_FILE="$SKINS_DIR/${SKIN_NAME}.yaml"
if [[ -f "$SKIN_FILE" && "$SKIN_NAME" != "default" ]]; then
  # Parse skin colors with bash (cached for 60s)
  SKIN_CACHE="/tmp/claude-skin-colors-${SKIN_NAME}"
  SKIN_CACHE_AGE=999
  if [[ -f "$SKIN_CACHE" ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      SKIN_CACHE_AGE=$(( $(date +%s) - $(stat -f %m "$SKIN_CACHE") ))
    else
      SKIN_CACHE_AGE=$(( $(date +%s) - $(stat -c %Y "$SKIN_CACHE") ))
    fi
  fi

  if [[ "$SKIN_CACHE_AGE" -gt 60 ]]; then
    # Source the parser and write cache
    # shellcheck source=engine/parse-yaml.sh
    source "$ENGINE_DIR/parse-yaml.sh"
    {
      get_yaml_value "$SKIN_FILE" "statusline.accent"  | tr -d '#'
      get_yaml_value "$SKIN_FILE" "statusline.dim"     | tr -d '#'
      get_yaml_value "$SKIN_FILE" "statusline.bar_fill"  | tr -d '#'
      get_yaml_value "$SKIN_FILE" "statusline.bar_empty" | tr -d '#'
      get_yaml_value "$SKIN_FILE" "statusline.icon"
    } > "$SKIN_CACHE" 2>/dev/null || true
  fi

  if [[ -f "$SKIN_CACHE" ]]; then
    i=0
    while IFS= read -r line; do
      case $i in
        0) ACCENT_HEX="$line" ;;
        1) DIM_HEX="$line" ;;
        2) BAR_FILL_HEX="$line" ;;
        3) BAR_EMPTY_HEX="$line" ;;
        4) ICON="$line" ;;
      esac
      i=$((i + 1))
    done < "$SKIN_CACHE"
  fi
fi

# Convert hex to ANSI RGB
hex_to_ansi() {
  local hex="$1"
  local r=$((16#${hex:0:2}))
  local g=$((16#${hex:2:2}))
  local b=$((16#${hex:4:2}))
  echo "\033[38;2;${r};${g};${b}m"
}

C_ACCENT=$(hex_to_ansi "$ACCENT_HEX")
C_DIM=$(hex_to_ansi "$DIM_HEX")
C_FILL=$(hex_to_ansi "$BAR_FILL_HEX")
C_EMPTY=$(hex_to_ansi "$BAR_EMPTY_HEX")
C_RESET="\033[0m"

# Context bar (10 chars wide)
FILLED=$((PCT / 10))
EMPTY=$((10 - FILLED))
BAR=""
for ((i=0; i<FILLED; i++)); do BAR+="${C_FILL}▓"; done
for ((i=0; i<EMPTY; i++)); do BAR+="${C_EMPTY}░"; done

# Color percentage by threshold
if [ "$PCT" -ge 90 ]; then
  CTX="${BAR} \033[31m${PCT}%${C_RESET}"
elif [ "$PCT" -ge 70 ]; then
  CTX="${BAR} \033[33m${PCT}%${C_RESET}"
else
  CTX="${BAR} \033[32m${PCT}%${C_RESET}"
fi

# Format cost
COST_FMT=$(printf "$%.2f" "$COST")

# Build output
GIT_PART=""
if [ -n "$GIT_INFO" ]; then
  GIT_PART=" ${C_DIM}⎇${C_RESET} ${GIT_INFO} ${C_DIM}|${C_RESET}"
fi

LINES_PART=""
if [ "$ADDED" != "0" ] || [ "$REMOVED" != "0" ]; then
  LINES_PART=" ${C_DIM}|${C_RESET} \033[32m+${ADDED}\033[0m \033[31m-${REMOVED}\033[0m"
fi

SKIN_LABEL=""
if [[ "$SKIN_NAME" != "default" ]]; then
  SKIN_LABEL="${C_ACCENT}${ICON}${C_RESET} "
fi

echo -e "${SKIN_LABEL}${C_ACCENT}${MODEL}${C_RESET} ${C_DIM}|${C_RESET} ${DIR} ${C_DIM}|${C_RESET}${GIT_PART} ${CTX} ${C_DIM}|${C_RESET} ${COST_FMT}${LINES_PART}"
