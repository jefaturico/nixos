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
  
  current_tags="$(read_int "$STATE_DIR/current_tags" 1)"
  new_tags=$(( current_tags ^ $1 ))
  
  if [ "$new_tags" -eq 0 ]; then
      new_tags="$(read_int "$STATE_DIR/last_active_tags" 1)"
  fi
  
  river-set-focused-tags "$new_tags"
''
