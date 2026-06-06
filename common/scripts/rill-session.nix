{ pkgs, pkgs-unstable }:
''
  #!${pkgs.dash}/bin/dash
  export XDG_CURRENT_DESKTOP=river
  export XDG_SESSION_TYPE=wayland

  # Ensure paths are set for spawns, prioritizing suid wrappers
  export PATH="/run/wrappers/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/jefaturico/bin:/run/current-system/sw/bin:$PATH"

  exec ${pkgs-unstable.river}/bin/river -c rill > /tmp/rill.log 2>&1
''
