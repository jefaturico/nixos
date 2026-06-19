{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  hostName = osConfig.networking.hostName;
  peerHost =
    if hostName == "galileo" then
      "ekman"
    else if hostName == "ekman" then
      "galileo"
    else
      null;

  symlinks = {
    nvim = "nvim";
    niri = "niri";
  };
in
{
  imports = [
    ./scripts.nix
    ./programs.nix
    ./services.nix
    ./session.nix
    ./wallust.nix
  ];

  home = {
    username = "jefaturico";
    homeDirectory = "/home/jefaturico";
    stateVersion = "26.05";

    file = {
      ".config/moxide/settings.toml".text = ''
        heading_completions = false
        title_headings = false
        link_filenames_only = true
      '';
      ".latexmkrc".text = ''
        $pdf_previewer = 'sioyek';
        $pdf_update_method = 0;
      '';
      ".local/bin/footclient" = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          overrides_file="''${XDG_CACHE_HOME:-$HOME/.cache}/wallust/footclient-overrides.bash"
          footclient_color_args=()
          [[ -r "$overrides_file" ]] && source "$overrides_file"

          set +e
          ${pkgs.foot}/bin/footclient "''${footclient_color_args[@]}" "$@"
          status=$?
          set -e

          if [[ "$status" -eq 220 ]]; then
            ${pkgs.systemd}/bin/systemctl --user start foot-server.service 2>/dev/null || true
            exec ${pkgs.foot}/bin/footclient "''${footclient_color_args[@]}" "$@"
          fi

          exit "$status"
        '';
      };
    }
    // (
      # Automatically symlink directories in ./dots/ to ~/.config/
      # We use mkOutOfStoreSymlink so that changes to files in the git repo
      # are immediately reflected without needing a 'nixos-rebuild switch'.
      builtins.listToAttrs (
        map (name: {
          name = ".config/${name}";
          value = {
            source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/dots/${symlinks.${name}}";
          };
        }) (builtins.attrNames symlinks)
      )
    );

  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "github.com" = {
        HostName = "github.com";
        User = "jefaturico";
        IdentityFile = "~/.ssh/id_${hostName}-github";
      };

      "*" = {
        ForwardAgent = false;
        AddKeysToAgent = "no";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };
    }
    // lib.optionalAttrs (peerHost != null) {
      ${peerHost} = {
        User = "jefaturico";
        IdentityFile = "~/.ssh/id_tailnet";
        IdentitiesOnly = true;
      };
    };
  };

}
