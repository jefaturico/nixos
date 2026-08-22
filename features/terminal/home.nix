{ pkgs, ... }:

# Foot runs as a shared server so new terminals open instantly. The palette
# is owned by `../theme.nix`; the wrapper below is what carries the current
# palette into every newly spawned client.
{
  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=16";
        pad = "24x24 center-when-maximized-and-fullscreen";
        initial-window-size-chars = "120x40";
        resize-by-cells = "no";
      };
      tweak.font-monospace-warn = "no";
    };
  };

  systemd.user.services.foot-server = {
    Unit = {
      Description = "Foot terminal server";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.foot}/bin/foot --server --override=initial-color-theme=dark";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.file.".local/bin/footclient" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      theme_file="''${XDG_CONFIG_HOME:-$HOME/.config}/foot/tinty-theme.ini"
      theme_overrides=()
      if [[ -r "$theme_file" ]]; then
        mapfile -t theme_overrides < <(
          ${pkgs.gawk}/bin/awk '
            /^\[colors-dark\]$/ { in_colors = 1; next }
            /^\[/ { in_colors = 0 }
            in_colors && /^[a-z0-9]+=/ {
              split($0, fields, "=")
              value = fields[2]
              sub(/[[:space:]]+#.*$/, "", value)
              print "--override=colors-dark." fields[1] "=" value
            }
          ' "$theme_file"
        )
      fi

      set +e
      ${pkgs.foot}/bin/footclient "''${theme_overrides[@]}" "$@"
      status=$?
      set -e

      if [[ "$status" -eq 220 ]]; then
        # Do not make opening a terminal depend on the server becoming
        # ready.  Repair it for subsequent clients while this invocation
        # immediately falls back to a regular foot process.
        ${pkgs.systemd}/bin/systemctl --user restart --no-block foot-server.service \
          >/dev/null 2>&1 || true
        exec ${pkgs.foot}/bin/foot "''${theme_overrides[@]}" "$@"
      fi

      exit "$status"
    '';
  };
}
