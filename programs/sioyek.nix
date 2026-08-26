{ ... }:

# Sioyek is the PDF reader.
{
  home-manager.users.jefaturico =
    { pkgs, ... }:
    {
      # Sioyek keeps one instance and reopens documents in the window it already
      # has, which is what is wanted from a link or a file manager but not from
      # the picker -- hence --new-window there and the package's own entry here.
      xdg.mimeApps.defaultApplications."application/pdf" = [ "sioyek.desktop" ];

      home.packages = [ pkgs.sioyek ];

      # Sioyek reads its defaults, then its own runtime-written auto.config, then
      # the user files -- of which ~/.config/sioyek/prefs_user.config is read last
      # and therefore wins. So nothing declared here can be quietly undone by a
      # setting sioyek saved for itself, and nothing sioyek saves for itself (the
      # window geometry it writes on resize) is declared here to be clobbered.
      #
      # super_fast_search swaps mupdf's search for an index sioyek builds in
      # memory while the document opens. It is unrelated to pdf-find's cache and
      # neither can use the other: sioyek's maps text to a rectangle inside one
      # open document and is thrown away on close, ours maps text to a page across
      # the whole library and lives on disk. Different questions, both worth
      # answering fast.
      xdg.configFile."sioyek/prefs_user.config".text = ''
        super_fast_search 1

        # Spelled with ~ rather than ./current-theme.config: a relative source is
        # resolved against the parent of the file doing the sourcing, and that
        # file is a symlink into the store, so the answer would depend on whether
        # sioyek resolves it before or after following the link.
        source ~/.config/sioyek/current-theme.config

        # TODO: search the library from inside sioyek. `new_command` splits its
        # template on whitespace *before* substituting and then runs an argv list
        # rather than a shell, so %{selected_text} arrives as a single argument
        # however many words it is, with no quoting to get wrong. Select a phrase
        # in a paper, press a key, get every page in the library about it.
        # Needs pdf-find to take an initial query and a --text flag first.
        #
        #   new_command _library_search pdf-find --text %{selected_text}
        #
        # and in keys_user.config:
        #
        #   _library_search <C-f>
      '';

      # One fragment per theme, and desktop-theme points current-theme.config at
      # whichever is current -- the same arrangement kitty uses in
      # programs/kitty.nix, for the same reason: sioyek has an include
      # directive, so the whole difference is a symlink and no file is rewritten.
      #
      # startup_commands is a whole line, not a list that can be appended to, so
      # toggle_statusbar is repeated rather than set once above where the theme
      # fragment would overwrite it.
      #
      # Only newly launched windows follow a theme change. Sioyek has
      # toggle_dark_mode and no setter, and does not report which mode it is in,
      # so a running instance cannot be driven to a known state -- F8 is how an
      # already-open document changes its mind.
      xdg.configFile."sioyek/sioyek-dark.config".text = ''
        startup_commands toggle_statusbar;toggle_dark_mode
      '';
      xdg.configFile."sioyek/sioyek-light.config".text = ''
        startup_commands toggle_statusbar
      '';
    };
}
