{ pkgs }:
''
  #!${pkgs.bash}/bin/bash
  # Float the focused window at 960x720, centered on a 1080p screen.
  # This script ALWAYS results in a floating, sized, centered window.

  riverctl toggle-float
  sleep 0.1

  # Snap to zero then add target size
  riverctl resize-view horizontal -10000
  riverctl resize-view vertical -10000
  riverctl resize-view horizontal 960
  riverctl resize-view vertical 720

  # Snap to origin then add target position
  riverctl move-view horizontal -10000
  riverctl move-view vertical -10000
  riverctl move-view horizontal 480
  riverctl move-view vertical 180
''
