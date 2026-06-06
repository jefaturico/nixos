{
  pkgs,
  pkgs-unstable,
  inputs,
  config,
  ...
}:

let
  # ── Individual script definitions ──
  batteryCheck = pkgs.writeScriptBin "battery-check" (import ./scripts/battery-check.nix { inherit pkgs; });
in
{
  home.packages =
    with pkgs;
    [
      # ── Session wrappers ──────────────────────────────────────────────────
      (pkgs.writeScriptBin "rill-session" (import ./scripts/rill-session.nix { inherit pkgs pkgs-unstable; }))

      # ── Rill layout generator ────────────────────────────────────────────
      (pkgs.callPackage ./pkgs/rill.nix {
        zig_0_16 = pkgs-unstable.zig;
        rillSource = inputs.rill;
      })

      # ── Utility scripts ─────────────────────────────────────────────────
      (pkgs.writeScriptBin "wlsetbg" (import ./scripts/wlsetbg.nix { inherit pkgs; }))
      (pkgs.writeScriptBin "wlsettheme" (import ./scripts/wlsettheme.nix { inherit pkgs; }))
      (pkgs.writeScriptBin "wldaynight" (import ./scripts/wldaynight.nix { inherit pkgs; }))
      (pkgs.writeScriptBin "rill-init" (import ./scripts/rill-init.nix { inherit pkgs; }))
      (pkgs.writeScriptBin "wdoc-find" (import ./scripts/wdoc-find.nix { inherit pkgs; }))
      (pkgs.writeScriptBin "fuzzel-bookmarks" (import ./scripts/fuzzel-bookmarks.nix { inherit pkgs; }))
      (pkgs.writeScriptBin "systeminfo" (import ./scripts/systeminfo.nix { inherit pkgs; }))
      (pkgs.writeScriptBin "wlbrightness" (import ./scripts/wlbrightness.nix { inherit pkgs; }))
      (pkgs.writeScriptBin "wlvolume" (import ./scripts/wlvolume.nix { inherit pkgs; }))
      (pkgs.writeScriptBin "wlscreenshot" (import ./scripts/wlscreenshot.nix { inherit pkgs; }))
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
