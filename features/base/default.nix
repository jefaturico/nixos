{ pkgs, ... }:

# Machine-independent foundation: boot entry policy, locale, the Nix daemon,
# garbage collection, memory/swap behaviour, and the handful of commands
# needed to repair the machine from a console.
{
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 5;
    };
    timeout = 0;
    efi.canTouchEfiVariables = true;
  };

  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "en_US.UTF-8";

  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  environment.systemPackages = with pkgs; [
    curl
    git
    neovim
    wget
  ];

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # Long builds are the norm on this flake; keep the progress bar and full
  # build logs without retyping the flags.
  programs.bash.interactiveShellInit = ''
    nix() {
      command nix --log-format bar-with-logs --print-build-logs "$@"
    }

    nixos-rebuild() {
      command nixos-rebuild --log-format bar-with-logs --print-build-logs "$@"
    }
  '';

  nixpkgs.config.allowUnfree = true;

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Deduplicate out of band. `auto-optimise-store` hashes every newly built
    # path inline, which lengthens each rebuild instead of the weekly job.
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-generations +5";
    };
  };

  # zram absorbs the working set in compressed RAM; a high swappiness is the
  # documented pairing because reclaim to zram is far cheaper than to disk.
  zramSwap.enable = true;
  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
    "vm.page-cluster" = 0;
  };

  services.fstrim.enable = true;

  system.stateVersion = "26.05";
}
