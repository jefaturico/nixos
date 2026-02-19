{ pkgs, osConfig, ... }:
{
  programs = {

    bash = {
      enable = true;
      shellAliases = { };
      sessionVariables = {

        TERM = "foot";
        BROWSER = "helium";
        DEFAULT_BROWSER = "helium";
      };

      initExtra = /* bash */ ''
        export FZF_DEFAULT_OPTS="--color=bg:-1,bg+:-1,gutter:-1"
        eval "$(zoxide init bash)"

        bind "set completion-ignore-case on"

        PS1='\[\e[34m\]\w\[\e[0m\] \[\e[32m\]λ\[\e[0m\] '

        shopt -s autocd
        shopt -s cdspell
        shopt -s checkwinsize
        shopt -s cmdhist
        shopt -s dirspell
        shopt -s globstar
        shopt -s histappend

        HISTCONTROL=ignoreboth:erasedups
        HISTSIZE=10000
        HISTFILESIZE=20000

      '';
    };

    foot = {
      enable = true;
      settings = {
        main = {
          font = "JetBrainsMono Nerd Font:size=16";
          pad = "24x24 center-when-maximized-and-fullscreen";
          include = "~/.cache/wal/colors-foot.ini";

        };
        colors = {
          alpha = if osConfig.networking.hostName == "galileo" then "0.98" else "0.8";
        };
      };
    };

    fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "JetBrainsMono Nerd Font:size=12";
          prompt = "\"λ \"";
          icons-enabled = "no";
          list-executables-in-path = "no";
          lines = 5;
          width = 40;
          horizontal-pad = 20;
          vertical-pad = 15;
          inner-pad = 5;
          include = "~/.cache/wal/colors-fuzzel.ini";
        };

        border = {
          width = 1;
          radius = 0;
        };
      };
    };

    git = {
      enable = true;
      settings = {
        user.name = "jefaturico";
        user.email = "jefaturico@gmail.com";
        init.defaultBranch = "main";
        safe.directory = "/etc/nixos";
      };
    };

    texlive = {
      enable = true;
      extraPackages = tpkgs: {
        inherit (tpkgs) scheme-full;
      };
    };

    zathura = {
      enable = true;
      package = pkgs.zathura.override {
        plugins = [
          pkgs.zathuraPkgs.zathura_pdf_mupdf
        ];
      };
      options = {
        render-loading = "false";
        guioptions = "none";
        page-cache-size = 512;
        continuous-hist-save = true;
        selection-clipboard = "clipboard";
      };
    };

    fzf = {
      enable = true;
    };
  };
}
