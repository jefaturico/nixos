{ pkgs }:
''
  #!${pkgs.bash}/bin/bash

  set -euo pipefail

  STATE_DIR="/tmp/river-state"
  
  mkdir -p "$STATE_DIR"
  
  read_int() {
      local path="$1"
      local fallback="$2"
  
      if [ -r "$path" ]; then
          cat "$path"
      else
          printf '%s\n' "$fallback"
      fi
  }
  
  write_int() {
      printf '%s\n' "$2" > "$1"
  }
  
  current_tags="$(read_int "$STATE_DIR/current_tags" 1)"
  previous_tags="$(read_int "$STATE_DIR/previous_tags" 1)"
  
  riverctl set-focused-tags "$previous_tags"
  
  write_int "$STATE_DIR/current_tags" "$previous_tags"
  write_int "$STATE_DIR/previous_tags" "$current_tags"
  
  if [ "$previous_tags" -ne 0 ]; then
      write_int "$STATE_DIR/last_active_tags" "$previous_tags"
  fi
''
