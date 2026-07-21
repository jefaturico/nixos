{ config, pkgs, ... }:

{
  home.packages = [
    pkgs.basedpyright
    pkgs.typst
    pkgs.tinymist
    pkgs.typstyle
    (pkgs.texliveSmall.withPackages (ps: [ ps.dvisvgm ]))
  ];

  home.file.".config/emacs".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos/dots/emacs";

  # `ispell-completion-at-point' expects a plain word list.  Without one,
  # global Corfu reports an error after nearly every word typed in text modes.
  home.file.".local/share/dict/words".source = "${pkgs.scowl}/share/dict/words.txt";
}
