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

  # ly is a console greeter, so it shares a TTY with the kernel and with
  # initrd's progress output. This hardware logs a benign
  # `ucsi_acpi USBC000:00: unknown error 256` at KERN_ERR on every boot, which
  # would otherwise land on top of the greeter. Print only genuinely fatal
  # levels to the console; everything is still recorded in the journal.
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;

  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "en_US.UTF-8";

  console.keyMap = "us";

  environment.systemPackages = with pkgs; [
    curl
    git
    neovim
    wget
  ];

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
