{ pkgs, ... }:

# Iapetus is a repurposed Lenovo laptop kept as the always-available headless
# host, reachable over the tailnet. It shares the base, user, and network
# modules with the graphical hosts and imports none of the desktop stack.
#
# It has no service role at the moment: it was the Syncthing hub until that
# was retired, and no replacement backup strategy has been chosen yet.
let
  rebuildPush = pkgs.writeScriptBin "rebuild-push" (
    import ../../features/development/rebuild-push.nix { inherit pkgs; }
  );
in
{
  imports = [
    ./hardware.nix
    ../../features/base
    ../../features/users
    # System half only: this host has no Home Manager, so the SSH *client*
    # configuration in features/network/home.nix does not apply here.
    ../../features/network/system.nix
  ];

  networking.hostName = "iapetus";

  # Reached over SSH from Tethys with that host's own key, in addition to the
  # shared tailnet identity.
  users.users.jefaturico.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKCYYIkAOD+VUHxB7shEKIxt5goUYv9kABwIKUU4hxgP jefaturico@tethys"
  ];

  # The lid stays shut on a shelf; nothing about closing it should stop the
  # server.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  services.thermald.enable = true;

  # A headless host has no interactive latency to protect, so bias the CPU
  # toward power on battery and let it boost only on mains.
  services.tlp = {
    enable = true;
    settings = {
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_BOOST_ON_BAT = 0;
      CPU_BOOST_ON_AC = 1;
      PCIE_ASPM_ON_BAT = "powersave";
    };
  };

  # This host owns the Git remote, so it carries the publish half of the
  # rebuild helper. The desktops get it through Home Manager.
  environment.systemPackages = [ rebuildPush ];

  # Half the RAM is enough compressed swap for a headless host, and leaves
  # the rest available as page cache.
  zramSwap.memoryPercent = 50;
  zramSwap.priority = 100;
}
