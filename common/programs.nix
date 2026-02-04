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

    emacs = {
      enable = true;
      package = pkgs.emacs-pgtk;
      extraPackages =
        epkgs: with epkgs; [
          vterm
          pdf-tools
          org-roam
          org-roam-ui
          treesit-auto
          vertico
          marginalia
          consult
          orderless
          corfu
          cape
          which-key
          all-the-icons
          doom-modeline
          visual-fill-column
          undo-fu
          evil
          evil-collection
          evil-org
          gcmh
          alert
          elfeed
          auctex
        ];
    };

    foot = {
      enable = true;
      settings = {
        main = {
          font = "JetBrainsMono Nerd Font:size=16";
          pad = "24x24 center-when-maximized-and-fullscreen";

        };
        colors = {
          alpha = if osConfig.networking.hostName == "galileo" then "0.97" else "0.8";
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

        };
        colors = {
          background = "ffffffff";
          text = "000000ff";
          match = "0031a9ff";
          selection = "c0deffff";
          selection-text = "000000ff";
          selection-match = "0031a9ff";
          border = "000000ff";
          prompt = "005f5fff";
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
      };

      mappings = {
        n = "scroll down";
        p = "scroll up";
        N = "navigate next";
        P = "navigate previous";
        "<C-n>" = "navigate next";
        "<C-p>" = "navigate previous";
        "<C-s>" = "toggle_statusbar";
      };
    };

    fzf = {
      enable = true;
    };
  };
}
