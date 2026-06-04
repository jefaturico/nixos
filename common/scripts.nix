{
  pkgs,
  ...
}:

let
  batteryCheck = pkgs.writeScriptBin "battery-check" (import ./scripts/battery-check.nix { inherit pkgs; });
in
{
  home.packages =
    with pkgs;
    [
      # dwl-startup: Runs WITHIN dwl via the -s flag.
      # This is crucial because it executes AFTER the Wayland socket is initialized.
      (pkgs.writeScriptBin "dwl-startup" (import ./scripts/dwl-startup.nix { inherit pkgs; }))

      # dwl-session: Wrapper script called by the display manager (Ly).
      (pkgs.writeScriptBin "dwl-session" (import ./scripts/dwl-session.nix { inherit pkgs; }))

      # river-session: Wrapper script for River, called by Ly display manager.
      (pkgs.writeScriptBin "river-session" (import ./scripts/river-session.nix { inherit pkgs; }))

      # river-startup: Environment setup run on River startup (wallpaper, dbus, services).
      (pkgs.writeScriptBin "river-startup" (import ./scripts/river-startup.nix { inherit pkgs; }))

      # river-init: River configuration script (keybindings, input, rules, layout).
      (pkgs.writeScriptBin "river-init" (import ./scripts/river-init.nix { inherit pkgs; }))

      # wlsetbg: Pure wallpaper manager (no theme logic).
      (pkgs.writeScriptBin "wlsetbg" (import ./scripts/wlsetbg.nix { inherit pkgs; }))

      # wlsettheme: Curated theme picker with mode-aware filtering.
      (pkgs.writeScriptBin "wlsettheme" (import ./scripts/wlsettheme.nix { inherit pkgs; }))

      # wldaynight: Toggle between light/dark, remembering specifically chosen themes.
      (pkgs.writeScriptBin "wldaynight" (import ./scripts/wldaynight.nix { inherit pkgs; }))
 
      # wdoc-find: Specialized document picker that prioritizes recently opened files in Zathura.
      (pkgs.writeScriptBin "wdoc-find" (import ./scripts/wdoc-find.nix { inherit pkgs; }))

      (pkgs.writeScriptBin "fuzzel-bookmarks" (import ./scripts/fuzzel-bookmarks.nix { inherit pkgs; }))

      (pkgs.writeScriptBin "systeminfo" (import ./scripts/systeminfo.nix { inherit pkgs; }))

      # wlbrightness: Minimalist brightness control with a hard 10% floor.
      (pkgs.writeScriptBin "wlbrightness" (import ./scripts/wlbrightness.nix { inherit pkgs; }))

      # wlvolume: Minimalist volume control.
      (pkgs.writeScriptBin "wlvolume" (import ./scripts/wlvolume.nix { inherit pkgs; }))

      # wlscreenshot: Screenshot utility using grim and slurp.
      (pkgs.writeScriptBin "wlscreenshot" (import ./scripts/wlscreenshot.nix { inherit pkgs; }))

      # fuzzel-history-run: Smart bash history search/execution.
      # Silent/Small -> Notification | Large/Long/TUI -> Terminal
      (pkgs.writeScriptBin "fuzzel-history-run" (import ./scripts/fuzzel-history-run.nix { inherit pkgs; }))

      (pkgs.writeScriptBin "single-instance" (import ./scripts/single-instance.nix { inherit pkgs; }))
    ]
    ++ [
      batteryCheck
    ];

  systemd.user.services.battery-check = {
    Unit.Description = "Battery Status Monitor Service";
    Service = {
      Type = "simple";
      ExecStart = "${batteryCheck}/bin/battery-check";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
