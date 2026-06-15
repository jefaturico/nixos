{ pkgs, lib, ... }:
let
  prepareVdirsyncerConfig = pkgs.writeShellScript "prepare-vdirsyncer-config" ''
    set -eu

    sops_secret_file="/run/secrets/vdirsyncer-google-calendar.env"
    legacy_secret_file="$HOME/nixos/secrets/vdirsyncer-google-calendar.env"
    runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/vdirsyncer"
    config_file="$runtime_dir/config"

    if [ -r "$sops_secret_file" ]; then
      secret_file="$sops_secret_file"
    elif [ -r "$legacy_secret_file" ]; then
      secret_file="$legacy_secret_file"
    else
      echo "Missing vdirsyncer OAuth secrets: $sops_secret_file or $legacy_secret_file" >&2
      exit 1
    fi

    . "$secret_file"
    : "''${GOOGLE_CALENDAR_CLIENT_ID:?Missing GOOGLE_CALENDAR_CLIENT_ID}"
    : "''${GOOGLE_CALENDAR_CLIENT_SECRET:?Missing GOOGLE_CALENDAR_CLIENT_SECRET}"

    ${pkgs.coreutils}/bin/install -m 700 -d "$runtime_dir"
    ${pkgs.coreutils}/bin/cat > "$config_file" <<EOF
    [general]
    status_path = "~/.local/share/vdirsyncer/status/"

    [pair calendars]
    a = "local_calendars"
    b = "google_calendars"
    collections = ["from b"]
    metadata = ["color"]
    conflict_resolution = "b wins"

    [storage local_calendars]
    type = "filesystem"
    path = "~/.calendars/"
    fileext = ".ics"

    [storage google_calendars]
    type = "google_calendar"
    token_file = "~/.local/share/vdirsyncer/google_calendar_token"
    client_id = "$GOOGLE_CALENDAR_CLIENT_ID"
    client_secret = "$GOOGLE_CALENDAR_CLIENT_SECRET"
    item_types = ["VEVENT"]
    EOF
    ${pkgs.coreutils}/bin/chmod 600 "$config_file"
  '';

  runVdirsyncer = pkgs.writeShellScript "run-vdirsyncer" ''
    exec ${pkgs.vdirsyncer}/bin/vdirsyncer --config "''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/vdirsyncer/config" sync
  '';
in
{
  services = {

    mako = {
      enable = true;
      settings = {
        font = "JetBrainsMono Nerd Font Mono 12";
        background-color = "#000000ff";
        text-color = "#ffffffff";
        border-color = "#ffffffff";
        border-size = 1;
        padding = "10";
        margin = "10";
        default-timeout = 2000;
        progress-color = "over #ffffffff";
        format = "<b>%s</b>\\n%b";
      };
      extraConfig = ''
        include=~/.cache/wallust/colors-mako

        [urgency=high]
        default-timeout=0
        ignore-timeout=1
        text-color=#ff0000
      '';
    };

    gammastep = {
      enable = true;
      provider = "manual";
      latitude = 40.4;
      longitude = -3.7;
      temperature = {
        day = 6500;
        night = 3500;
      };
      settings = {
        general = {
          adjustment-method = "wayland";
          fade = 1;
        };
      };
    };

    udiskie = {
      enable = true;
      automount = true;
      notify = true;
      tray = "never";
    };

    vdirsyncer = {
      enable = true;
      frequency = "*:0/15";
    };
  };
  systemd.user.services.foot-server = {
    Unit = {
      Description = "Foot terminal server";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.foot}/bin/foot --server";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.mako = {
    Service = {
      Restart = "always";
      ExecStartPre = "${pkgs.writeShellScript "mako-pre" ''
        mkdir -p "$HOME/.cache/wallust"
        touch "$HOME/.cache/wallust/colors-mako"
        touch "$HOME/.cache/wallust/colors-foot.ini"
        touch "$HOME/.cache/wallust/colors-fuzzel.ini"
      ''}";
    };
  };

  systemd.user.services.vdirsyncer.Service = {
    ExecStartPre = prepareVdirsyncerConfig;
    ExecStart = lib.mkForce runVdirsyncer;
  };
}
