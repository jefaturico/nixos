{ pkgs }:
''
  #!${pkgs.bash}/bin/bash

  STATE_DIR="/tmp/river-state"
  mkdir -p "$STATE_DIR"

  printf '1\n' > "$STATE_DIR/current_tags"
  printf '1\n' > "$STATE_DIR/previous_tags"
  printf '1\n' > "$STATE_DIR/last_active_tags"
''
