{
  pkgs,
  dotfiles,
  ...
}:
let
  # Emacs, mu4e and the mu binary have to come from the same nixpkgs: mu4e
  # refuses to talk to a mu of another version. All three are taken from
  # unstable, which has what Arch has (emacs 31, mu 1.14). Stable is on
  # emacs 30 and mu 1.12. `mu` itself is in home/mail.nix.
  emacs = (pkgs.unstable.emacsPackagesFor pkgs.unstable.emacs-pgtk).emacsWithPackages (
    epkgs: with epkgs; [
      mu4e
      # The packages that package.el had installed. init.el still says
      # `:ensure t`, which finds these and downloads nothing.
      gruvbox-theme
      popper
      # org-timeblock was installed too, but nixpkgs marks it as broken.
      # init.el does not load it. If you want it back, package.el still
      # works: M-x package-install RET org-timeblock
    ]
  );
in
{
  # ---- Emacs ---------------------------------------------------------------
  # Was ~/.emacs
  home.file.".emacs".source = dotfiles "emacs/init.el";

  # Was a hand-written ~/.config/systemd/user/emacs.service (--fg-daemon,
  # started with the user session).
  services.emacs = {
    enable = true;
    package = emacs;
    startWithUserSession = true;
  };

  # ---- Neovim --------------------------------------------------------------
  # Was ~/.config/nvim (init.lua + lazy-lock.json). lazy.nvim keeps managing
  # the plugins, the same way as on Arch. The whole directory is linked so
  # lazy can update its lock file.
  #
  # Not programs.neovim: that module writes its own init.lua.
  xdg.configFile."nvim".source = dotfiles "nvim";

  home.packages = [
    emacs
    pkgs.neovim
    # What init.lua's plugins call at runtime, next to gcc, tree-sitter,
    # marksman and libtexprintf from home/packages.nix.
    pkgs.cargo # blink.cmp builds its matcher from source
    pkgs.rustc
  ];
}
