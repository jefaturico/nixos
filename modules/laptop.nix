{ pkgs, ... }:
let
  # balanced on the charger or the dock, power-saver on battery.
  onAC = "balanced";
  onBattery = "power-saver";

  setProfile = pkgs.writeShellScript "power-profile-auto" ''
    profile=${onBattery}
    for supply in /sys/class/power_supply/*; do
      if [ "$(cat "$supply/type")" = Mains ] && [ "$(cat "$supply/online")" = 1 ]; then
        profile=${onAC}
      fi
    done
    exec ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set "$profile"
  '';
in
{
  # ---- Power -------------------------------------------------------------
  # power-profiles-daemon, which is what Framework, the Arch wiki, the NixOS
  # wiki and nixos-hardware all recommend for the AMD boards. TLP, which the
  # Arch install used, is advised against on this platform.
  services.power-profiles-daemon.enable = true;

  # PPD never changes profile by itself. This does it when the charger is
  # plugged or unplugged, and once at boot. Setting a profile by hand
  # (`powerprofilesctl set performance`) holds until the next plug event.
  systemd.services.power-profile-auto = {
    description = "Set the power profile from the power source";
    wantedBy = [ "multi-user.target" ];
    requires = [ "power-profiles-daemon.service" ];
    after = [ "power-profiles-daemon.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = setProfile;
    };
  };
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ACTION=="change", RUN+="${pkgs.systemd}/bin/systemctl --no-block start power-profile-auto.service"
  '';

  # On battery PPD also lets the panel trade colour accuracy for power
  # (ABM), which can look washed out. To stop it from touching the panel:
  # systemd.services.power-profiles-daemon.serviceConfig.ExecStart = [
  #   ""
  #   "${pkgs.power-profiles-daemon}/libexec/power-profiles-daemon --block-action=amdgpu_panel_power"
  # ];

  services.upower.enable = true;

  # ---- Sleep ---------------------------------------------------------------
  # Hibernate needs: swap at least as big as the RAM (32G for 30G), the
  # kernel told where to resume from, and an initrd that unlocks the disk
  # before looking for the image. The first two come from
  # hosts/coriolis/disko.nix, the third from modules/boot.nix.
  #
  # The power key hibernates. niri has `disable-power-key-handling`, so
  # logind is the one that reacts.
  services.logind.settings.Login.HandlePowerKey = "hibernate";

  # ---- Keyboard ------------------------------------------------------------
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        global = {
          # The Arch file had `macto_repeat_interval`, which keyd ignored.
          macro_repeat_interval = 60;
          macro_repeat_timeout = 200;
        };
        main.capslock = "leftcontrol";
      };
    };
  };

  # ---- Fingerprint reader --------------------------------------------------
  # Off: the lid is closed when docked, which is most of the time.
  # nixos-hardware turns it on by default.
  services.fprintd.enable = false;

  # ---- Speakers ------------------------------------------------------------
  # The speakers fire downwards and sound thin. This is Framework's
  # equaliser preset, as a pipewire filter on the built-in speakers only.
  hardware.framework.laptop13.audioEnhancement.enable = true;

  # ---- From nixos-hardware (framework-amd-ai-300-series) -------------------
  # On by default, nothing to set here:
  #   fwupd             firmware updates: fwupdmgr refresh && fwupdmgr update
  #   fstrim            weekly TRIM
  #   framework kmod    battery charge limit and LEDs as normal sysfs files
  #   amd_pstate=active, and amdgpu.dcdebugmask=0x10 against the panel
  #   self-refresh hangs
}
