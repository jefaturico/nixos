{
  inputs,
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
  tailnetHost = {
    User = "jefaturico";
    IdentityFile = "~/.ssh/id_tailnet";
    IdentitiesOnly = true;
  };
in
{
  imports = [
    ./niri/home.nix
    ./scripts.nix
    ./programs.nix
    ./theme.nix
  ];

  home = {
    username = "jefaturico";
    homeDirectory = "/home/jefaturico";
    stateVersion = "26.05";
    packages = [
      inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.codex
    ];

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

          overrides_file="''${XDG_CACHE_HOME:-$HOME/.cache}/matugen/dynamic/foot-overrides.bash"
          footclient_color_args=()
          if [[ -r "$overrides_file" ]]; then
            # This file is generated from a trusted declarative Matugen
            # template and contains only a Bash array of Foot overrides.
            # shellcheck disable=SC1090
            source "$overrides_file"
          fi

          set +e
          ${pkgs.foot}/bin/footclient "''${footclient_color_args[@]}" "$@"
          status=$?
          set -e

          if [[ "$status" -eq 220 ]]; then
            # Do not make opening a terminal depend on the server becoming
            # ready.  Repair it for subsequent clients while this invocation
            # immediately falls back to a regular foot process.
            ${pkgs.systemd}/bin/systemctl --user restart --no-block foot-server.service \
              >/dev/null 2>&1 || true
            exec ${pkgs.foot}/bin/foot "''${footclient_color_args[@]}" "$@"
          fi

          exit "$status"
        '';
      };
    };
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
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };
    }
    // lib.optionalAttrs (peerHost != null) {
      ${peerHost} = tailnetHost;
      iapetus = tailnetHost;
    };
  };
}
