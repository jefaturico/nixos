{ config, pkgs, ... }:
{
  imports = [
    ./tty.nix
    ./secrets.nix
    ./syncthing.nix
    ./eureka.nix
    ./unfree-packages.nix
  ];

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "en_US.UTF-8";

  networking = {
    networkmanager.enable = true;
    firewall.trustedInterfaces = [ "tailscale0" ];
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "altgr-intl";
  };

  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        FastConnectable = true;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };

  services = {
    displayManager = {
      ly = {
        enable = true;
        settings = {
          background = "0x00000000";
          foreground = "0x00AAAAAA";
          full_color = true;
          animation = "none";
          animation_frame_delay = 10;
          colormix_col1 = "0x40FFFFFF";
          colormix_col2 = "0x40AAAAAA";
          colormix_col3 = "0x20000000";
          restore = true;
          session_log = "null";
          hide_version_string = true;
          hide_key_hints = true;
          hide_borders = false;
        };
      };
    };

    udisks2.enable = true;
    dbus.enable = true;

    flatpak = {
      enable = true;
      overrides = {
        global = {
          Context.filesystems = [
            "xdg-config/gtk-3.0:ro"
            "xdg-config/gtk-4.0:ro"
          ];
          Environment = {
            GTK_CSD = "0";
            QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
          };
        };
      };
      packages = [
        "com.bitwarden.desktop"
        "com.stremio.Stremio"
      ];
      remotes = [
        {
          name = "flathub";
          location = "https://flathub.org/repo/flathub.flatpakrepo";
        }
      ];
      update.auto = {
        enable = true;
        onCalendar = "daily";
      };
    };

    pipewire = {
      enable = true;
      pulse.enable = true;
    };

    openssh = {
      enable = true;
      openFirewall = false;
      settings.PasswordAuthentication = false;
      settings.KbdInteractiveAuthentication = false;
      settings.PermitRootLogin = "no";
    };

    tailscale = {
      enable = true;
      openFirewall = true;
      useRoutingFeatures = "client";
      extraSetFlags = [ "--hostname=${config.networking.hostName}" ];
    };

    keyd = {
      enable = true;
      keyboards = {
        default = {
          ids = [ "*" ];
          settings = {
            main = {
              capslock = "overload(control, esc)";
              menu = "leftmeta";
            };
          };
        };
      };
    };
  };

  environment.etc."libinput/local-overrides.quirks".text = ''
    [keyd Virtual Keyboard]
    MatchName=keyd virtual keyboard
    AttrKeyboardIntegration=internal
  '';

  programs = {
    dconf.enable = true;
  };

  xdg.portal = {
    enable = true;
  };

  users.users.jefaturico = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfx6y39zNZYSLw18oOwuX8N+aStamNANfZJtCrBEK3I tailnet"
    ];
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "render"
      "input"
    ];
  };

  environment.systemPackages = with pkgs; [
    sops
    ssh-to-age
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    roboto
    corefonts
  ];

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

  zramSwap.enable = true;
  services.fstrim.enable = true;
  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
  };

  system.stateVersion = "25.11";
}
