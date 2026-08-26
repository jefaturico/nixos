{ ... }:

# `pdf-find`: the picker that decides which document the PDF reader opens.
#
# Two things shape everything below. The window has to be usable before
# anything has been scanned, so nothing here blocks it: the list is served
# from a cache and refreshed behind it, and the text extraction that makes
# full-text search possible runs in a session of its own that outlives the
# window it was launched from.
#
# And a query spans two scopes at once. Searching `deleuze concept` means
# "the page about that concept, in the paper by that author" -- but the
# author's name is on page one and in the filename, while the concept is on
# page 112. So a record carries both: the page's text for the concept, and
# the document's identity for the author. That is why the unit is a page and
# why fzf, not ripgrep, does the matching.
{
  home-manager.users.jefaturico =
    { config, pkgs, ... }:
    let
      # One definition of "a PDF worth finding", shared by the warm pass and the
      # live scan so the two can never disagree about what exists.
      pdfFindScan = pkgs.writeShellApplication {
        name = "pdf-find-scan";
        runtimeInputs = [ pkgs.fd ];
        # fd skips hidden directories and does not follow symlinks, which already
        # covers ~/.cache, the trash, and every `result` link into the store;
        # what is left to name are the ordinary-looking directories full of
        # vendored copies. --no-ignore-vcs is the deliberate part: LaTeX output
        # is gitignored precisely because it is generated, and generated is
        # exactly what a paper being written is.
        text = builtins.readFile ../scripts/pdf-find-scan.sh;
      };

      # One PDF, one worker. Everything it needs to decide is in its own record
      # file, so the pass that calls it can be a flat xargs with no join, no
      # shared index, and no lock.
      pdfFindExtract = pkgs.writeShellApplication {
        name = "pdf-find-extract";
        runtimeInputs = with pkgs; [
          coreutils
          gawk
          poppler-utils
        ];
        text = builtins.readFile ../scripts/pdf-find-extract.sh;
      };

      pdfFindWarm = pkgs.writeShellApplication {
        name = "pdf-find-warm";
        runtimeInputs = with pkgs; [
          coreutils
          findutils
          gawk
          util-linux
          pdfFindExtract
          pdfFindScan
        ];
        text = builtins.readFile ../scripts/pdf-find-warm.sh;
      };

      # Every record in either mode is the same three fields -- path, page,
      # label -- so the picker's field options, its preview and its enter binding
      # are stated once and do not change when the mode does. Only the label is
      # ever displayed or matched; the first two exist so that choosing a row
      # knows which document and which page it meant.
      pdfFindList = pkgs.writeShellApplication {
        name = "pdf-find-list";
        runtimeInputs = with pkgs; [
          coreutils
          gawk
          pdfFindScan
        ];
        text = builtins.readFile ../scripts/pdf-find-list.sh;
      };

      pdfFindPages = pkgs.writeShellApplication {
        name = "pdf-find-pages";
        runtimeInputs = [ pkgs.coreutils ];
        text = builtins.readFile ../scripts/pdf-find-pages.sh;
      };

      # A page-sized record cannot be shown whole in a list, so the preview is
      # not a luxury here -- it is how a hit is judged. It costs one `sed -n` on
      # a local text file, which is why it can afford to be on by default.
      pdfFindPreview = pkgs.writeShellApplication {
        name = "pdf-find-preview";
        runtimeInputs = with pkgs; [
          coreutils
          gnused
          ripgrep
        ];
        text = builtins.readFile ../scripts/pdf-find-preview.sh;
      };

      pdfFindOpen = pkgs.writeShellApplication {
        name = "pdf-find-open";
        runtimeInputs = with pkgs; [
          sioyek
          util-linux
        ];
        # A page is the finest a result can be aimed, and that is sioyek's limit
        # rather than a choice. --focus-text looks like the way past it: it scores
        # every line on a page by longest common subsequence against a string and
        # marks the winner, which is exactly the "jump to the line, not the page"
        # this would want.
        #
        # It cannot be used. focus_text runs at main.cpp:642 but the document is
        # not opened until main.cpp:668, so on the invocation that opens a file it
        # dereferences a document that does not exist yet. Launching with it
        # segfaults outright; worse, sending it to an *already running* sioyek for
        # a file that window does not have open takes the running instance down
        # with it -- measured here, twice out of two, killing a reader that was
        # open on another document. A crash that costs someone their reading
        # session is not a fair price for landing on a line instead of a page.
        #
        # It works only when the named file is already open in a window, which is
        # to say only from an extension running inside sioyek. If upstream ever
        # moves that block below the open, this becomes a two-line change.
        text = builtins.readFile ../scripts/pdf-find-open.sh;
      };

      pdfFindPick = pkgs.writeShellApplication {
        name = "pdf-find-pick";
        runtimeInputs = with pkgs; [
          fzf
          pdfFindList
          pdfFindOpen
          pdfFindPages
          pdfFindPreview
        ];
        # Both modes are the same fzf over the same fields; only the candidate
        # list is swapped. fzf *is* the search -- there is no subprocess per
        # keystroke and no ripgrep -- which is what makes the query fuzzy,
        # multi-term and order-independent, and what lets `deleuze concept` match
        # an author against a word on a page. fzf refuses to search text it does
        # not display, so both live in the one field it is shown: the identity is
        # appended past the page text, where it matches without being read.
        #
        # --exact is what makes a page-sized record searchable at all. Fuzzy
        # matching looks for a subsequence, and over three thousand characters of
        # page text almost any short query appears as one by accident: measured
        # here, `piper vivelo` matched 314 of 325 pages, most of them in the wrong
        # document, against a true answer of none. Exact matching brings that to
        # exactly the pages that hold the words.
        #
        # Nothing the query needed is lost. Terms are still AND-ed, still in any
        # order, still found anywhere in the record -- what goes is only the
        # licence to skip letters. Matching is by substring rather than by whole
        # word, so `database` still finds `databases`, and --exact inverts the
        # meaning of a leading quote, so `'databse` puts fuzzy back for one term.
        #
        # No --sync either: it holds the first frame back until the initial list
        # is complete, which is the wait this arrangement exists to avoid.
        text = builtins.readFile ../scripts/pdf-find-pick.sh;
      };

      pdfFind = pkgs.writeShellApplication {
        name = "pdf-find";
        runtimeInputs = with pkgs; [
          config.programs.kitty.package
          util-linux
          pdfFindPick
          pdfFindWarm
        ];
        # The warm pass is put in a session of its own before the window opens,
        # not after it closes: it is the reason full-text search has anything to
        # search, and it has to survive a picker that is dismissed a second from
        # now. kitty takes the command to run as trailing arguments, so --class
        # -- which is how the niri window rule finds this window -- has to
        # precede it; see desktop-network in features/compositor/system.nix.
        text = builtins.readFile ../scripts/pdf-find.sh;
      };
    in
    {
      # Only the entry point goes on PATH under a memorable name; everything
      # else is reached through it and named nowhere but here.
      home.packages = [ pdfFind ];
    };
}
