{ pkgs, ... }:

# An event-driven posture and movement reminder. It watches real activity
# through Wayland idle notifications rather than a wall clock, and stays
# quiet during gaming, fullscreen video, active MPRIS playback, and while the
# screen is locked.
#
# It is niri-specific only in how it inspects the focused window, so the unit
# refuses to start under any other session.
let
  movementReminder = import ./movement-reminder.nix { inherit pkgs; };
in
{
  environment.systemPackages = [ movementReminder ];

  systemd.user.services.movement-reminder = {
    description = "Event-driven movement and posture reminder daemon";
    unitConfig.ConditionEnvironment = "XDG_CURRENT_DESKTOP=niri";
    after = [
      "niri.service"
      "fnott.service"
    ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${movementReminder}/bin/movement-reminder";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
