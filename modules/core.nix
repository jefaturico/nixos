{ pkgs, username, ... }:
{
  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "en_US.UTF-8";

  networking.networkmanager.enable = true;
  # Do not hold the boot until the network is up, nothing here needs it.
  systemd.services.NetworkManager-wait-online.enable = false;

  # Without a regulatory domain the MT7925 stays on the world defaults,
  # which the Arch wiki says can limit it to 2.4GHz and Wi-Fi 4. Arch had
  # none set. Abroad, until the next reboot: sudo iw reg set <country code>
  hardware.wirelessRegulatoryDatabase = true;
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom=ES
  '';

  # Root cannot log in, sudo is the way in. The price: no emergency shell
  # when the boot fails. Recovery is an older generation from the boot
  # menu, or the installer USB stick.
  users.users.root.hashedPassword = "!";

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      # Lets the user manage connections without sudo. On Arch polkit did that.
      "networkmanager"
    ];
    # No password here on purpose. Set it once during the install:
    #   nixos-enter --root /mnt -c 'passwd jefaturico'
  };

  # The few things wanted system-wide (root shell, rescue). Everything else
  # is in home/packages.nix.
  environment.systemPackages = with pkgs; [
    git
    iw
    neovim
    htop
    unzip
    curl
  ];

  # man-db and man-pages, plus the development pages (man 2, man 3).
  documentation = {
    man.enable = true;
    dev.enable = true;
  };
  environment.extraOutputsToInstall = [ "man" ];

  # nix-index provides the "command not found" hook instead, see
  # modules/nix.nix. The stock one does not work with flakes.
  programs.command-not-found.enable = false;
}
