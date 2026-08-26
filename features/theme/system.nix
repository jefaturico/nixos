{ pkgs, ... }:

let
  desktopTheme = pkgs.callPackage ./desktop-theme.nix { };
in
{
  environment.systemPackages = [ desktopTheme ];

  # Nothing persists a theme across a reboot except the state file, so the
  # stored choice has to be pushed back out once the session exists — dconf
  # is per-user but the portal only starts republishing once there is a
  # session to publish to.
  systemd.user.services.desktop-theme = {
    description = "Apply the stored light/dark theme to the running session";
    unitConfig.ConditionEnvironment = "XDG_CURRENT_DESKTOP=niri";
    after = [ "niri.service" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${desktopTheme}/bin/desktop-theme apply";
    };
  };
}
