{ pkgs }:
''
  #!${pkgs.bash}/bin/bash

  set -euo pipefail

  STATE_DIR="/tmp/river-state"
  
  if [ "$#" -ne 1 ]; then
      exit 1
  fi
  
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
  
  new_tags="$1"
  current_tags="$(read_int "$STATE_DIR/current_tags" 1)"
  
  if [ "$current_tags" -ne "$new_tags" ]; then
      write_int "$STATE_DIR/previous_tags" "$current_tags"
  fi
  
  riverctl set-focused-tags "$new_tags"
  write_int "$STATE_DIR/current_tags" "$new_tags"
  
  if [ "$new_tags" -ne 0 ]; then
      write_int "$STATE_DIR/last_active_tags" "$new_tags"
  fi
''
