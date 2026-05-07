#!/bin/bash
# Claude Skins — pure-bash YAML parser
# Handles the simple subset of YAML used by skin files:
#   - Top-level scalars:          key: value
#   - One level of nesting:       section:\n  key: value
#   - Two levels of nesting:      section:\n  sub:\n    key: value
#   - Block scalars (|):          key: |\n    line1\n    line2
#   - Inline maps:                key: { field1: "v1", field2: "v2" }
#
# Public API:
#   get_yaml_value  <file> <dotted.key>   — print scalar value (trimmed, unquoted)
#   get_yaml_block  <file> <dotted.key>   — print block-scalar content (preserves newlines)
#   get_yaml_value_with_default <skin_file> <default_file> <dotted.key>
#   get_yaml_block_with_default <skin_file> <default_file> <dotted.key>

# ---------------------------------------------------------------------------
# _yaml_unquote <string>
# Strip surrounding single or double quotes from a value string.
# ---------------------------------------------------------------------------
_yaml_unquote() {
  local v="$1"
  # Remove surrounding double quotes
  if [[ "$v" == '"'*'"' ]]; then
    v="${v#\"}"
    v="${v%\"}"
  # Remove surrounding single quotes
  elif [[ "$v" == "'"*"'" ]]; then
    v="${v#\'}"
    v="${v%\'}"
  fi
  echo "$v"
}

# ---------------------------------------------------------------------------
# _yaml_strip_comment <string>
# Strip trailing inline comment (# ...) but NOT if the value is quoted.
# ---------------------------------------------------------------------------
_yaml_strip_comment() {
  local v="$1"
  # If the trimmed value starts with a quote, don't strip anything —
  # the hash is inside the string (e.g., "#0E0520")
  local trimmed="${v#"${v%%[! ]*}"}"
  if [[ "$trimmed" == '"'* || "$trimmed" == "'"* ]]; then
    echo "$v"
  else
    # Safe to strip trailing # comment
    local stripped="${v%%#*}"
    stripped="${stripped%"${stripped##*[! ]}"}"
    echo "$stripped"
  fi
}

# ---------------------------------------------------------------------------
# get_yaml_value <file> <dotted.key>
# Returns the scalar value for a dotted key path.
# Examples:
#   get_yaml_value skin.yaml "name"
#   get_yaml_value skin.yaml "terminal.background"
#   get_yaml_value skin.yaml "terminal.palette.black"
#   get_yaml_value skin.yaml "statusline.accent"
#   get_yaml_value skin.yaml "tools.sounds"
# ---------------------------------------------------------------------------
get_yaml_value() {
  local file="$1"
  local dotkey="$2"

  [[ ! -f "$file" ]] && return

  # Split dotted key into parts
  local IFS='.'
  read -ra parts <<< "$dotkey"
  local depth="${#parts[@]}"
  unset IFS

  local p0="${parts[0]}"
  local p1="${parts[1]:-}"
  local p2="${parts[2]:-}"

  local in_section=0
  local in_subsection=0
  local section_indent=""
  local subsection_indent=""
  local in_block=0           # are we inside a block scalar we're skipping?

  while IFS= read -r line; do
    # Skip comment-only lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    # Get raw indent level
    local raw_indent="${line%%[^ ]*}"
    local indent_len="${#raw_indent}"

    # Detect and skip block scalars we don't want
    if [[ $in_block -eq 1 ]]; then
      # Block content has MORE indentation than its key line
      if [[ $indent_len -gt $block_indent_len ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
        continue
      else
        in_block=0
      fi
    fi

    # Strip leading whitespace for value extraction
    local stripped="${line#"${raw_indent}"}"

    # ----------------------------------------------------------------
    # depth == 1 : top-level key
    # ----------------------------------------------------------------
    if [[ $depth -eq 1 ]]; then
      # Match: "key: value"  or  "key:"
      if [[ "$stripped" =~ ^([^:]+):[[:space:]]*(.*) ]]; then
        local k="${BASH_REMATCH[1]}"
        local v="${BASH_REMATCH[2]}"
        # Trim trailing whitespace from key
        k="${k%"${k##*[! ]}"}"
        if [[ "$k" == "$p0" && $indent_len -eq 0 ]]; then
          # Skip block scalar indicator
          [[ "$v" == "|" || "$v" == "|-" || "$v" == "|+" ]] && return
          local val
          val=$(_yaml_strip_comment "$v")
          _yaml_unquote "$val"
          return
        fi
      fi
    fi

    # ----------------------------------------------------------------
    # depth == 2 : section.key
    # ----------------------------------------------------------------
    if [[ $depth -eq 2 ]]; then
      # Detect section header at indent 0
      if [[ $indent_len -eq 0 && "$stripped" =~ ^([^:]+):[[:space:]]*(.*) ]]; then
        local k="${BASH_REMATCH[1]}"
        k="${k%"${k##*[! ]}"}"
        if [[ "$k" == "$p0" ]]; then
          in_section=1
          in_subsection=0
          section_indent="  "   # expect 2-space indent for children
          continue
        else
          in_section=0
        fi
      fi

      if [[ $in_section -eq 1 && $indent_len -gt 0 ]]; then
        if [[ "$stripped" =~ ^([^:]+):[[:space:]]*(.*) ]]; then
          local k="${BASH_REMATCH[1]}"
          local v="${BASH_REMATCH[2]}"
          k="${k%"${k##*[! ]}"}"
          if [[ "$k" == "$p1" ]]; then
            [[ "$v" == "|" || "$v" == "|-" || "$v" == "|+" ]] && return
            local val
            val=$(_yaml_strip_comment "$v")
            _yaml_unquote "$val"
            return
          fi
        fi
      fi
    fi

    # ----------------------------------------------------------------
    # depth == 3 : section.subsection.key
    # ----------------------------------------------------------------
    if [[ $depth -eq 3 ]]; then
      if [[ $indent_len -eq 0 && "$stripped" =~ ^([^:]+):[[:space:]]*(.*) ]]; then
        local k="${BASH_REMATCH[1]}"
        k="${k%"${k##*[! ]}"}"
        if [[ "$k" == "$p0" ]]; then
          in_section=1
          in_subsection=0
          continue
        else
          in_section=0
          in_subsection=0
        fi
      fi

      if [[ $in_section -eq 1 ]]; then
        if [[ $indent_len -eq 2 && "$stripped" =~ ^([^:]+):[[:space:]]*(.*) ]]; then
          local k="${BASH_REMATCH[1]}"
          k="${k%"${k##*[! ]}"}"
          if [[ "$k" == "$p1" ]]; then
            in_subsection=1
            continue
          else
            in_subsection=0
          fi
        fi

        if [[ $in_subsection -eq 1 && $indent_len -ge 4 ]]; then
          if [[ "$stripped" =~ ^([^:]+):[[:space:]]*(.*) ]]; then
            local k="${BASH_REMATCH[1]}"
            local v="${BASH_REMATCH[2]}"
            k="${k%"${k##*[! ]}"}"
            if [[ "$k" == "$p2" ]]; then
              [[ "$v" == "|" || "$v" == "|-" || "$v" == "|+" ]] && return
              local val
              val=$(_yaml_strip_comment "$v")
              _yaml_unquote "$val"
              return
            fi
          fi
        fi
      fi
    fi

  done < "$file"
}

# ---------------------------------------------------------------------------
# get_yaml_block <file> <dotted.key>
# Returns the content of a YAML block scalar (|) for the given key.
# Strips the common leading indentation from all content lines.
# ---------------------------------------------------------------------------
get_yaml_block() {
  local file="$1"
  local dotkey="$2"

  [[ ! -f "$file" ]] && return

  local IFS='.'
  read -ra parts <<< "$dotkey"
  local depth="${#parts[@]}"
  unset IFS

  local p0="${parts[0]}"
  local p1="${parts[1]:-}"

  local in_section=0
  local capturing=0
  local block_base_indent=-1
  local result=""

  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    local raw_indent="${line%%[^ ]*}"
    local indent_len="${#raw_indent}"
    local stripped="${line#"${raw_indent}"}"

    # If we're capturing block content
    if [[ $capturing -eq 1 ]]; then
      # Empty line — include as blank line in block
      if [[ "$line" =~ ^[[:space:]]*$ ]]; then
        result+=$'\n'
        continue
      fi

      # Set baseline indent from first non-empty content line
      if [[ $block_base_indent -eq -1 ]]; then
        block_base_indent=$indent_len
      fi

      # If indentation drops to or below the key's own level, we're done
      if [[ $indent_len -lt $block_base_indent ]]; then
        capturing=0
        break
      fi

      # Strip the base indent and append
      local content="${line:$block_base_indent}"
      if [[ -n "$result" ]]; then
        result+=$'\n'"$content"
      else
        result="$content"
      fi
      continue
    fi

    # ----------------------------------------------------------------
    # depth == 1 : top-level key
    # ----------------------------------------------------------------
    if [[ $depth -eq 1 ]]; then
      if [[ $indent_len -eq 0 && "$stripped" =~ ^([^:]+):[[:space:]]*(.*) ]]; then
        local k="${BASH_REMATCH[1]}"
        local v="${BASH_REMATCH[2]}"
        k="${k%"${k##*[! ]}"}"
        if [[ "$k" == "$p0" ]]; then
          if [[ "$v" == "|" || "$v" == "|-" || "$v" == "|+" ]]; then
            capturing=1
            block_base_indent=-1
            result=""
          fi
        fi
      fi
    fi

    # ----------------------------------------------------------------
    # depth == 2 : section.key
    # ----------------------------------------------------------------
    if [[ $depth -eq 2 ]]; then
      if [[ $indent_len -eq 0 && "$stripped" =~ ^([^:]+):[[:space:]]*(.*) ]]; then
        local k="${BASH_REMATCH[1]}"
        k="${k%"${k##*[! ]}"}"
        if [[ "$k" == "$p0" ]]; then
          in_section=1
          continue
        else
          in_section=0
        fi
      fi

      if [[ $in_section -eq 1 && $indent_len -gt 0 ]]; then
        if [[ "$stripped" =~ ^([^:]+):[[:space:]]*(.*) ]]; then
          local k="${BASH_REMATCH[1]}"
          local v="${BASH_REMATCH[2]}"
          k="${k%"${k##*[! ]}"}"
          if [[ "$k" == "$p1" ]]; then
            if [[ "$v" == "|" || "$v" == "|-" || "$v" == "|+" ]]; then
              capturing=1
              block_base_indent=-1
              result=""
            fi
          fi
        fi
      fi
    fi

  done < "$file"

  # Strip trailing newlines from result (YAML block literal behavior)
  # but preserve the content
  printf '%s' "$result"
}

# ---------------------------------------------------------------------------
# get_yaml_inline_field <inline_map_string> <field_name>
# Extract a field from an inline map like: { sound: "Purr", icon: "◆" }
# ---------------------------------------------------------------------------
get_yaml_inline_field() {
  local map="$1"
  local field="$2"

  # Strip outer braces and whitespace
  local inner="${map#\{}"
  inner="${inner%\}}"

  # Split on commas (simple: no nested commas in this schema)
  local IFS=','
  local parts
  read -ra parts <<< "$inner"
  unset IFS

  for part in "${parts[@]}"; do
    # Trim leading/trailing whitespace
    part="${part#"${part%%[! ]*}"}"
    part="${part%"${part##*[! ]}"}"

    if [[ "$part" =~ ^([^:]+):[[:space:]]*(.*) ]]; then
      local k="${BASH_REMATCH[1]}"
      local v="${BASH_REMATCH[2]}"
      k="${k%"${k##*[! ]}"}"
      if [[ "$k" == "$field" ]]; then
        _yaml_unquote "$v"
        return
      fi
    fi
  done
}

# ---------------------------------------------------------------------------
# get_yaml_event_field <file> <event_name> <field_name>
# Specialized parser for tools.events.EVENT: { field: value }
# ---------------------------------------------------------------------------
get_yaml_event_field() {
  local file="$1"
  local event_name="$2"
  local field_name="$3"

  [[ ! -f "$file" ]] && return

  local in_tools=0
  local in_events=0

  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    local raw_indent="${line%%[^ ]*}"
    local indent_len="${#raw_indent}"
    local stripped="${line#"${raw_indent}"}"

    if [[ $indent_len -eq 0 ]]; then
      if [[ "$stripped" =~ ^tools:[[:space:]]* ]]; then
        in_tools=1
        in_events=0
        continue
      else
        in_tools=0
        in_events=0
      fi
    fi

    if [[ $in_tools -eq 1 && $indent_len -eq 2 ]]; then
      if [[ "$stripped" =~ ^events:[[:space:]]* ]]; then
        in_events=1
        continue
      else
        in_events=0
      fi
    fi

    if [[ $in_events -eq 1 && $indent_len -ge 4 ]]; then
      if [[ "$stripped" =~ ^([^:]+):[[:space:]]*(.*) ]]; then
        local k="${BASH_REMATCH[1]}"
        local v="${BASH_REMATCH[2]}"
        k="${k%"${k##*[! ]}"}"
        if [[ "$k" == "$event_name" ]]; then
          get_yaml_inline_field "$v" "$field_name"
          return
        fi
      fi
    fi

  done < "$file"
}

# ---------------------------------------------------------------------------
# get_yaml_value_with_default <skin_file> <default_file> <dotted.key>
# Try skin file first; fall back to default file if value is empty.
# ---------------------------------------------------------------------------
get_yaml_value_with_default() {
  local skin_file="$1"
  local default_file="$2"
  local dotkey="$3"

  local val
  val=$(get_yaml_value "$skin_file" "$dotkey")
  if [[ -z "$val" && -f "$default_file" ]]; then
    val=$(get_yaml_value "$default_file" "$dotkey")
  fi
  printf '%s' "$val"
}

# ---------------------------------------------------------------------------
# get_yaml_block_with_default <skin_file> <default_file> <dotted.key>
# ---------------------------------------------------------------------------
get_yaml_block_with_default() {
  local skin_file="$1"
  local default_file="$2"
  local dotkey="$3"

  local val
  val=$(get_yaml_block "$skin_file" "$dotkey")
  if [[ -z "$val" && -f "$default_file" ]]; then
    val=$(get_yaml_block "$default_file" "$dotkey")
  fi
  printf '%s' "$val"
}

# ---------------------------------------------------------------------------
# get_yaml_event_field_with_default <skin_file> <default_file> <event> <field>
# ---------------------------------------------------------------------------
get_yaml_event_field_with_default() {
  local skin_file="$1"
  local default_file="$2"
  local event_name="$3"
  local field_name="$4"

  local val
  val=$(get_yaml_event_field "$skin_file" "$event_name" "$field_name")
  if [[ -z "$val" && -f "$default_file" ]]; then
    val=$(get_yaml_event_field "$default_file" "$event_name" "$field_name")
  fi
  printf '%s' "$val"
}
