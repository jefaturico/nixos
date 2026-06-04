{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
{
  # Bootloader and system-level localization.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "en_US.UTF-8";

  networking = {
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [ 22 ];
  };

  # System-wide keyboard layout for TTY and X11 (though we mostly use Wayland).
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
  };

  services = {
    # Ly is a TUI display manager.
    displayManager.ly = {
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

    # Manual creation of a Wayland session entry for dwl.
    # This allows display managers like Ly to "see" and launch dwl.
    displayManager.sessionPackages = [
      (pkgs.runCommand "dwl-session"
        {
          passthru.providedSessions = [ "dwl" ];
        }
        ''
          mkdir -p $out/share/wayland-sessions
          cat <<EOF > $out/share/wayland-sessions/dwl.desktop
          [Desktop Entry]
          Name=dwl
          Comment=Dynamic Window Manager for Wayland
          Exec=dwl-session
          Type=Application
          EOF
        ''
      )

      # Register River session for login managers.
      (pkgs.runCommand "river-session"
        {
          passthru.providedSessions = [ "river" ];
        }
        ''
          mkdir -p $out/share/wayland-sessions
          cat <<EOF > $out/share/wayland-sessions/river.desktop
          [Desktop Entry]
          Name=river
          Comment=A dynamic tiling Wayland compositor
          Exec=river-session
          Type=Application
          EOF
        ''
      )
    ];

    udisks2.enable = true;
    dbus.enable = true;

    # Declarative Flatpak management via nix-flatpak.
    flatpak = {
      enable = true;
      packages = [
        "org.jamovi.jamovi"
      ]
      ++ lib.optionals (config.networking.hostName != "coriolis") [
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
    };

    openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      settings.KbdInteractiveAuthentication = false;
    };

    # Keyd handles low-level keyboard remapping (Caps Lock as Control/Esc).
    keyd = {
      enable = true;
      keyboards = {
        default = {
          ids = [ "*" ];
          settings = {
            main = {
              capslock = "overload(control, esc)";
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

  programs.dconf.enable = true;

  # XDG Portals enable features like screen sharing and file pickers in Wayland.
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-wlr
      pkgs.xdg-desktop-portal-gnome
    ];
    config = {
      common.default = [ "gtk" ];
      wlroots = {
        "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      };
    };
  };

  users.users.jefaturico = {
    isNormalUser = true;
    extraGroups = [
      "wheel" # Sudo access
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
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Automatically links identical files in the Nix store to save space.
    auto-optimise-store = true;
  };

  # Periodic cleanup of old system generations.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Performance and lifecycle optimizations.
  zramSwap.enable = true;
  services.fstrim.enable = true;
  boot.kernel.sysctl = {
    "vm.swappiness" = 100;
  };

  system.stateVersion = "25.11";
}
