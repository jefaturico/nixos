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
    if hostName == "titan" then
      "tethys"
    else if hostName == "tethys" then
      "titan"
    else
      null;
  oldPeerHost =
    if hostName == "titan" then
      "ekman"
    else if hostName == "tethys" then
      "galileo"
    else
      null;
  symlinks = { };
in
{
  imports = [
    ./scripts.nix
    ./emacs.nix
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
      "documents/notes/config.yml".text = ''
        select_origin: directory
        files_origin: "."
        nodes_origin: ""
        links_origin: ""
        nodes_online: ""
        links_online: ""
        images_origin: ""
        export_target: "."
        history: false
        focus_max: 2
        record_types:
          undefined:
            fill: '#858585'
            stroke: '#858585'
        link_types:
          undefined:
            stroke: simple
            color: '#e1e1e1'
        references_as_nodes: false
        references_type_label: references
        record_filters: []
        graph_background_color: '#ffffff'
        graph_highlight_color: '#ff6a6a'
        graph_highlight_on_hover: true
        graph_text_size: 10
        graph_arrows: true
        node_size_method: degree
        node_size: 10
        node_size_max: 20
        node_size_min: 2
        attraction_force: 200
        attraction_distance_max: 250
        attraction_vertical: 0
        attraction_horizontal: 0
        views: {}
        record_metas: []
        generate_id: always
        link_context: tooltip
        hide_id_from_record_header: false
        title: "Notes"
        author: ""
        description: ""
        keywords: []
        link_symbol: ""
        csl: ""
        bibliography: ""
        csl_locale: ""
        css_custom: ""
        devtools: false
        lang: en
      '';
      ".latexmkrc".text = ''
        $pdf_previewer = 'zathura';
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
      # Transitional authentication for a peer that still advertises its old name.
      ${oldPeerHost} = {
        User = "jefaturico";
        IdentityFile = "~/.ssh/id_tailnet";
        IdentitiesOnly = true;
      };
      iapetus = {
        User = "jefaturico";
        IdentityFile = "~/.ssh/id_tailnet";
        IdentitiesOnly = true;
      };
      odin = {
        User = "jefaturico";
        IdentityFile = "~/.ssh/id_tailnet";
        IdentitiesOnly = true;
      };
    };
  };

}
