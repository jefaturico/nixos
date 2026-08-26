{ pkgs, ... }:

# The system-wide light/dark switch. The applications themselves are themed
# by their own files; this one owns the decision and the plumbing that
# distributes it.
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

  home-manager.users.jefaturico =
    { pkgs, lib, ... }:
    {
      # GTK's own files carry no light/dark preference: the live value comes
      # from `org/gnome/desktop/interface` through the portal, and
      # `desktop-theme` is the only thing that writes it. Pinning it here — in
      # dconf.settings or in a gtk3/gtk4 `gtk-application-prefer-dark-theme` —
      # would silently undo the user's choice on every rebuild.
      gtk = {
        enable = true;
        theme = {
          name = "Adwaita";
          package = pkgs.gnome-themes-extra;
        };
      };

      # Route Qt through the GTK platform theme so it follows the same setting
      # rather than needing a second, parallel theme declaration.
      qt = {
        enable = true;
        platformTheme.name = "gtk3";
      };

      # fuzzel would fall back to its stock colors if its symlink were
      # missing, so the fragment has to exist before the first login rather
      # than from the session service.
      home.activation.desktopThemeFiles = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${desktopTheme}/bin/desktop-theme files
      '';
    };
}
