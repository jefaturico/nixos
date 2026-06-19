{
  pkgs,
  lib,
  config,
  ...
}:
let
  syncthingDevices = {
    galileo.id = "OQUT2EC-CERWR4S-PJCPFUU-BUMZJZL-EVH66K6-I2YKDX3-6A7RS3I-Z3LLFAW";
    ekman.id = "2STWXA4-JBLZ5FM-ZDFPSR2-VE63IJP-SI4LVAW-ECSVLL4-PRFI27E-6VELQQG";
  };

  sharedWith = devices: builtins.filter (device: device != config.networking.hostName) devices;
in
{
  imports = [
    ./secrets.nix
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
      defaultSession = "niri";
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
      packages = [
        "com.bitwarden.desktop"
        "org.jamovi.jamovi"
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

    syncthing = {
      enable = true;
      user = "jefaturico";
      dataDir = "/home/jefaturico";
      openDefaultPorts = true;
      overrideDevices = false;
      overrideFolders = false;
      settings = {
        devices = syncthingDevices;
        folders = {
          projects = {
            id = "4pmxv-syxrh";
            path = "/home/jefaturico/projects";
            devices = sharedWith [
              "galileo"
              "ekman"
            ];
          };
          calcurse = {
            id = "5rdcv-wpnjr";
            path = "~/.local/share/calcurse";
            devices = sharedWith [
              "galileo"
              "ekman"
            ];
          };
          wallpapers = {
            id = "bppru-7tfft";
            path = "~/images/wallpapers";
            devices = sharedWith [
              "galileo"
              "ekman"
            ];
          };
          tasks = {
            id = "pngaf-ufcfi";
            path = "/home/jefaturico/.local/share/task";
            devices = sharedWith [
              "galileo"
              "ekman"
            ];
          };
          "zathura metadata" = {
            id = "rqfbg-5r2be";
            path = "~/.local/share/zathura";
            devices = sharedWith [
              "galileo"
              "ekman"
            ];
          };
          documents = {
            id = "twsxa-tfzj6";
            path = "/home/jefaturico/documents";
            devices = sharedWith [
              "galileo"
              "ekman"
            ];
          };
          nixos = {
            id = "y2dqc-sjty3";
            path = "~/nixos";
            devices = sharedWith [
              "galileo"
              "ekman"
            ];
          };
        };
        options = {
          urAccepted = -1;
        };
      };
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
    chromium = {
      enable = true;
      extraOpts = {
        BookmarkBarEnabled = false;
        BrowserSignin = 0;
        DefaultBrowserSettingEnabled = false;
        DefaultSearchProviderEnabled = true;
        DefaultSearchProviderName = "DuckDuckGo";
        DefaultSearchProviderSearchURL = "https://duckduckgo.com/?q={searchTerms}";
        DefaultSearchProviderSuggestURL = "https://duckduckgo.com/ac/?q={searchTerms}&type=list";
        SyncDisabled = true;
        TranslateEnabled = false;
      };
      initialPrefs = {
        browser.enabled_labs_experiments = [
          "extension-mime-request-handling@2"
          "overlay-scrollbars@2"
          "scroll-tabs@2"
        ];
        bookmark_bar.show_on_all_tabs = false;
        intl.selected_languages = "en-US,en";
        profile.name = "Your Chromium";
      };
    };

    dconf.enable = true;
    niri.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
    config = {
      niri = {
        default = [
          "gnome"
          "gtk"
        ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
    };
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
    wget
    git
    curl
    htop
    sops
    ssh-to-age
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  nixpkgs.config = {
    allowUnfree = false;
    allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "code"
        "nvidia-x11"
        "nvidia-kernel-modules"
        "nvidia-settings"
        "obsidian"
        "vscode"
        "vscode-fhs"
      ];
  };
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
