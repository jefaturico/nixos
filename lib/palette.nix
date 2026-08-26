# Monokai Pro: the default filter for dark, the light filter for light. This
# is the one place the palette is written down. kitty takes the sixteen ANSI
# colours in `ansi` verbatim, in order; fuzzel and mako take the handful of
# derived roles under `ui`, so the terminal, the launcher and the
# notifications can never drift apart. Values are bare six-digit hex, because
# the three consumers each spell the same colour differently: kitty wants
# `#2d2a2e`, mako `#2d2a2e`, and fuzzel `2d2a2eff` with an alpha byte.
{
  dark = {
    # 0-7 regular, 8-15 bright. Monokai Pro only distinguishes the two at the
    # grey end, so 9-14 repeat 1-6.
    ansi = [
      "403e41"
      "ff6188"
      "a9dc76"
      "ffd866"
      "fc9867"
      "ab9df2"
      "78dce8"
      "fcfcfa"
      "727072"
      "ff6188"
      "a9dc76"
      "ffd866"
      "fc9867"
      "ab9df2"
      "78dce8"
      "fcfcfa"
    ];

    ui = {
      background = "2d2a2e";
      text = "fcfcfa";
      # bright0, the palette's own "comment" grey: dim enough to read as
      # secondary against the background without disappearing into it.
      dim = "727072";
      accent = "ffd866";
      selection = "403e41";
      selectionText = "fcfcfa";
      border = "727072";
    };
  };

  light = {
    ansi = [
      "29242a"
      "e14775"
      "269d69"
      "b16803"
      "e16032"
      "7058be"
      "1c8ca8"
      "8b8489"
      "a59fa0"
      "e14775"
      "269d69"
      "b16803"
      "e16032"
      "7058be"
      "1c8ca8"
      "29242a"
    ];

    # The light filter inverts which end of the palette is usable: its colour 0
    # is the near-black foreground, so the selection background comes from 8
    # and the selected text from 15 instead.
    ui = {
      background = "faf4f2";
      text = "29242a";
      dim = "8b8489";
      accent = "b16803";
      selection = "a59fa0";
      selectionText = "29242a";
      border = "8b8489";
    };
  };
}
