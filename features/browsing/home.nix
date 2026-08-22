{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  firefoxAddons = inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
  browserApplications = [
    "librewolf.desktop"
    "brave-browser.desktop"
  ];
in
{
  home = {
    file = {
      ".config/librewolf/librewolf/profiles.ini".force = true;
      ".config/librewolf/librewolf/default/.keep".force = true;
      ".config/librewolf/librewolf/default/user.js".force = true;
      ".config/librewolf/librewolf/default/chrome/userChrome.css".force = true;
      ".config/librewolf/librewolf/default/chrome/userContent.css".force = true;
      ".config/librewolf/librewolf/default/search.json.mozlz4".force = true;
    };
    packages = [ pkgs.brave ];
    sessionVariables = {
      BROWSER = "librewolf";
      DEFAULT_BROWSER = "librewolf";
    };
  };

  xdg.mimeApps.defaultApplications = {
    "text/html" = browserApplications;
    "x-scheme-handler/http" = browserApplications;
    "x-scheme-handler/https" = browserApplications;
    "x-scheme-handler/about" = browserApplications;
    "x-scheme-handler/unknown" = browserApplications;
  };

  programs.librewolf = {
    enable = true;
    # LibreWolf 154 follows the XDG profile root, while Home Manager 26.05
    # still defaults to the legacy ~/.librewolf location.
    configPath = ".config/librewolf/librewolf";
    profilesPath = ".config/librewolf/librewolf";

    policies = {
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DontCheckDefaultBrowser = true;
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      SearchEngines.Default = "DuckDuckGo";
      UserMessaging = {
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        MoreFromMozilla = false;
        SkipOnboarding = true;
        UrlbarInterventions = false;
        WhatsNew = false;
      };
      ExtensionSettings = {
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
        };
        "vimium-c@gdh1995.cn" = {
          installation_mode = "force_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/vimium-c/latest.xpi";
        };
      };
    };

    profiles.default = {
      extensions.packages = with firefoxAddons; [
        bitwarden
        vimium-c
      ];
      settings = {
        "browser.aboutwelcome.enabled" = false;
        "browser.compactmode.show" = true;
        "browser.in-content.dark-mode" = true;
        "browser.startup.homepage_override.mstone" = "ignore";
        "browser.tabs.allow_transparent_browser" = true;
        "browser.theme.content-theme" = 0;
        "browser.theme.native-theme" = false;
        "browser.theme.toolbar-theme" = 0;
        "browser.uidensity" = 1;
        "browser.urlbar.maxRichResults" = 0;
        "browser.urlbar.openViewOnFocus" = false;
        "layout.css.prefers-color-scheme.content-override" = 0;
        "ui.systemUsesDarkTheme" = 1;
        "browser.urlbar.suggest.bookmark" = false;
        "browser.urlbar.suggest.engines" = false;
        "browser.urlbar.suggest.history" = false;
        "browser.urlbar.suggest.openpage" = false;
        "browser.urlbar.suggest.quickactions" = false;
        "browser.urlbar.suggest.shortcuts" = false;
        "browser.urlbar.suggest.topsites" = false;
        "extensions.autoDisableScopes" = 0;
        "mozilla.widget.use-argb-visuals" = true;
        "sidebar.revamp" = false;
        "sidebar.verticalTabs" = false;
        "sidebar.visibility" = "hide-sidebar";
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "widget.transparent-windows" = true;
        "widget.wayland.opaque-region.enabled" = false;
        "widget.wayland.use-opaque-region" = false;
      };
      # TODO: Implement live theme hot-reloading without browser restarts using
      # the WebExtension Theme API (browser.theme.update) + Native Messaging host
      # (e.g. Pywalfox / MatugenFox native messaging host) triggered via apply-desktop-theme.
      search = {
        force = true;
        default = "ddg";
      };
      userChrome = ''
        @import url("tinty.css");
      '';
      userContent = ''
        /* Hide all scrollbars across all web pages */
        * {
          scrollbar-width: none !important;
        }
      '';
    };
  };

  # Home Manager normally links these files only when the generation changes.
  # Reassert the managed profile on every activation so deleting the live
  # profile is recoverable by rebuilding the same generation.
  home.activation.restoreLibreWolfProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    restore_link() {
      source=$1
      target=$2
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$target")"
      if [ -d "$target" ] && [ ! -L "$target" ]; then
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -rf "$target"
      fi
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/ln -sfnT "$source" "$target"
    }

    profile_root="$HOME/.config/librewolf/librewolf"
    restore_link ${config.home.file.".config/librewolf/librewolf/profiles.ini".source} \
      "$profile_root/profiles.ini"
    restore_link ${config.home.file.".config/librewolf/librewolf/default/.keep".source} \
      "$profile_root/default/.keep"
    restore_link ${config.home.file.".config/librewolf/librewolf/default/user.js".source} \
      "$profile_root/default/user.js"
    restore_link ${
      config.home.file.".config/librewolf/librewolf/default/chrome/userChrome.css".source
    } \
      "$profile_root/default/chrome/userChrome.css"
    restore_link ${
      config.home.file.".config/librewolf/librewolf/default/chrome/userContent.css".source
    } \
      "$profile_root/default/chrome/userContent.css"
    restore_link ${config.home.file.".config/librewolf/librewolf/default/search.json.mozlz4".source} \
      "$profile_root/default/search.json.mozlz4"

    extensions_source="${config.home.file.".config/librewolf/librewolf/default/extensions".source}"
    extensions_target="$profile_root/default/extensions"
    if [ -L "$extensions_target" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f "$extensions_target"
    fi
    $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$extensions_target"
    for ext in "$extensions_source"/*; do
      if [ -e "$ext" ]; then
        restore_link "$ext" "$extensions_target/$(${pkgs.coreutils}/bin/basename "$ext")"
      fi
    done
  '';
}
