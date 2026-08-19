{ config, pkgs, ... }:
let
  rebuildPush = pkgs.writeScriptBin "rebuild-push" (
    import ../../common/scripts/rebuild-push.nix { inherit pkgs; }
  );
in
{
  imports = [
    ./hardware.nix
    ../../common/syncthing.nix
  ];

  networking = {
    hostName = "iapetus";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      trustedInterfaces = [ "tailscale0" ];
    };
  };

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
  };
  boot.loader.timeout = 0;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "en_US.UTF-8";

  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  users.users.jefaturico = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfx6y39zNZYSLw18oOwuX8N+aStamNANfZJtCrBEK3I tailnet"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKCYYIkAOD+VUHxB7shEKIxt5goUYv9kABwIKUU4hxgP jefaturico@tethys"
    ];
  };

  services = {
    openssh = {
      enable = true;
      openFirewall = false;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    tailscale = {
      enable = true;
      openFirewall = true;
      useRoutingFeatures = "client";
      extraSetFlags = [ "--hostname=${config.networking.hostName}" ];
    };

    thermald.enable = true;
    fstrim.enable = true;

    logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchDocked = "ignore";
      HandleLidSwitchExternalPower = "ignore";
    };

    tlp = {
      enable = true;
      settings = {
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
        CPU_BOOST_ON_BAT = 0;
        CPU_BOOST_ON_AC = 1;
        PCIE_ASPM_ON_BAT = "powersave";
      };
    };
  };

  environment.variables = {
    EDITOR = "hx";
    VISUAL = "hx";
  };

  environment.systemPackages = with pkgs; [
    rebuildPush
    helix
    git
    curl
    wget
    htop
    rsync
  ];

  programs.bash.interactiveShellInit = ''
    nix() {
      command nix --log-format bar-with-logs --print-build-logs "$@"
    }

    nixos-rebuild() {
      command nixos-rebuild --log-format bar-with-logs --print-build-logs "$@"
    }
  '';

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-generations +10";
  };

  zramSwap = {
    enable = true;
    memoryPercent = 50;
    priority = 100;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
    "vm.page-cluster" = 0;
  };

  system.stateVersion = "26.05";
}
