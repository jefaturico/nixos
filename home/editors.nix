{
  config,
  pkgs,
  dotfiles,
  ...
}:
let
  # Emacs, mu4e and the mu binary have to come from the same nixpkgs: mu4e
  # refuses to talk to a mu of another version. All three are taken from
  # unstable (emacs 31, mu 1.14). Stable is on emacs 30 and mu 1.12. `mu`
  # itself is in home/mail.nix.
  unstableEmacsPackages = pkgs.unstable.emacsPackagesFor pkgs.unstable.emacs-pgtk;

  # Python with its language server. pyflakes is the only checker: it
  # reports real mistakes (syntax, undefined names, unused imports) and no
  # style or type complaints.
  python = pkgs.python3.withPackages (
    ps: [ ps.python-lsp-server ] ++ ps.python-lsp-server.optional-dependencies.pyflakes
  );
in
{
  # The config is dotfiles/emacs/init.el. The colours and the font are not in
  # it, they are set below.
  home.file.".emacs".source = dotfiles "emacs/init.el";

  # stylix would build its theme into the Emacs package, so every theme
  # would be a different Emacs and switching would restart it. The same
  # theme is loaded from a file at runtime instead (home/theme-switch.nix).
  stylix.targets.emacs.enable = false;

  programs.emacs = {
    enable = true;
    package = pkgs.unstable.emacs-pgtk;
    extraConfig = ''
      (set-face-attribute 'default nil
                          :font (font-spec :family "${config.stylix.fonts.monospace.name}"
                                           :size ${toString config.stylix.fonts.sizes.terminal}.0))
      ;; The colours come from stylix, as a theme file the theme switch
      ;; replaces (home/theme-switch.nix). Reloaded whenever a switch is done,
      ;; so every open Emacs follows.
      (setq base16-theme-256-color-source 'colors)
      (add-to-list 'custom-theme-load-path "~/.config/theme/")
      (defun my-apply-theme (&rest _)
        (mapc #'disable-theme custom-enabled-themes)
        (load-theme 'base16-stylix t))
      (my-apply-theme)
      (require 'filenotify)
      (file-notify-add-watch
       (expand-file-name "~/.local/state/") '(change)
       (lambda (event)
         (when (equal (file-name-nondirectory (nth 2 event)) "theme")
           (my-apply-theme))))
    '';
    # `epkgs` would be the stable package set, so these are named from the
    # unstable one directly.
    extraPackages = epkgs: [
      unstableEmacsPackages.mu4e
      # Draws the stylix palette (home/theme-switch.nix).
      unstableEmacsPackages.base16-theme

      # Typst: the mode, and the grammar it highlights with.
      unstableEmacsPackages.typst-ts-mode
      (unstableEmacsPackages.treesit-grammars.with-grammars (
        grammars: [ grammars.tree-sitter-typst ]
      ))
    ];
  };

  # Runs as a daemon from login, so `emacsclient` opens instantly.
  services.emacs = {
    enable = true;
    startWithUserSession = true;
  };

  # The language servers Emacs talks to. Typst's (tinymist) is in
  # home/packages.nix, next to typst itself.
  home.packages = [ python ];
}
