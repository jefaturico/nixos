{ config, pkgs, ... }:

# Sioyek is the PDF reader. The rest of this file is `pdf-find`, the picker
# that decides which document it opens.
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
let
  terminal = "${config.programs.kitty.package}/bin/kitty";

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
    text = ''
      set -euo pipefail
      exec fd \
        --type f \
        --extension pdf \
        --no-ignore-vcs \
        --exclude node_modules \
        --exclude .venv \
        --exclude venv \
        --exclude result \
        --exclude 'result-*' \
        . "$HOME"
    '';
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
    text = ''
      set -euo pipefail
      file="''${1:-}"
      [ -n "$file" ] || exit 0
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/pdf-find"

      key=$(printf '%s' "$file" | sha256sum | cut -c1-32)
      record="$cache/meta/$key"
      text="$cache/text/$key.txt"

      stamp=$(stat -c '%Y %s' "$file" 2>/dev/null) || exit 0
      mtime=''${stamp%% *}
      size=''${stamp##* }

      # The record is touched even when there is nothing to do: the warm pass
      # decides what to prune by looking at which records this pass left
      # alone, so skipping still has to leave a mark.
      if [ -f "$record" ] && [ "$(cut -f1,2 "$record" | tr '\t' ' ')" = "$stamp" ]; then
        touch "$record"
        exit 0
      fi

      # Half the papers worth searching are called 2301.04567v2.pdf, so the
      # author's name exists nowhere but here. fzf will not match text it does
      # not display, so this is appended to the end of a row rather than
      # hidden in a field of its own: past the page text, where it is matched
      # but effectively never seen.
      blob=$( { pdfinfo "$file" 2>/dev/null || true; } | awk '
        /^(Title|Author|Subject|Keywords):/ {
          sub(/^[^:]*:[[:space:]]*/, "")
          if (length($0) > 0) fields[n++] = $0
        }
        END {
          out = ""
          for (i = 0; i < n; i++) out = out " " fields[i]
          gsub(/[[:space:]]+/, " ", out)
          sub(/^ /, "", out)
          print out
        }
      ')

      pages=$( { pdfinfo "$file" 2>/dev/null || true; } | awk '
        /^Pages:/ { print $2; exit }
      ')
      [ -n "$pages" ] || pages=0

      # One line per page, so that line N of the cache is page N of the
      # document -- which is what lets the preview find a page with a single
      # `sed -n`, and what makes a result address something sioyek can
      # actually open. Empty pages are still printed, because a gap would
      # slide every page after it out of alignment.
      status=ok
      if ! timeout 60 pdftotext -q -eol unix "$file" - 2>/dev/null | awk -v pages="$pages" '
        function emit(  t) {
          if (pages > 0 && page > pages) { buf = ""; return }
          t = buf
          gsub(/[[:space:]]+/, " ", t)
          sub(/^ /, "", t)
          sub(/ $/, "", t)
          print page "\t" t
          buf = ""
        }
        BEGIN { page = 1; buf = "" }
        {
          n = split($0, part, /\f/)
          for (i = 1; i <= n; i++) {
            if (i > 1) { emit(); page++ }
            buf = buf " " part[i]
          }
        }
        END {
          emit()
          while (page < pages) { page++; print page "\t" }
        }
      ' >"$text.$$"; then
        status=fail
      fi

      # Nothing came out: a scan with no text layer, or a document pdftotext
      # will not open. The answer will be the same next time, so the record
      # remembers it and the file is not tried again until it changes on disk.
      if [ "$status" = ok ] \
        && awk -F'\t' 'length($2) > 0 { found = 1 } END { exit found ? 0 : 1 }' "$text.$$"; then
        mv -f "$text.$$" "$text"
      else
        if [ "$status" = ok ]; then status=empty; fi
        rm -f "$text.$$" "$text"
      fi

      printf '%s\t%s\t%s\t%s\t%s\n' "$mtime" "$size" "$status" "$blob" "$file" >"$record.$$"
      mv -f "$record.$$" "$record"
    '';
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
    text = ''
      set -euo pipefail
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/pdf-find"
      mkdir -p "$cache/meta" "$cache/text"

      # One pass at a time. A second launch while the first is still running
      # has nothing to add, so it leaves rather than queues.
      exec 9>"$cache/warm.lock"
      flock -n 9 || exit 0

      # This is the only writer of the caches below, and each lands with a
      # single mv. The picker never writes them, which is why a picker killed
      # the instant something is chosen cannot leave one half-written.
      pdf-find-scan >"$cache/paths.new"
      mv -f "$cache/paths.new" "$cache/paths"

      # Every worker below leaves its record newer than this file, whether it
      # rewrote it or merely skipped it, so afterwards the records older than
      # the stamp are exactly the PDFs that are gone. Comparing against a file
      # rather than a clock is what makes that true: `date +%s` is accurate to
      # the second, and a pass over an unchanged library finishes well inside
      # one, which would leave the previous pass's records looking current.
      : >"$cache/stamp"

      # Extraction is the expensive half and nobody is waiting for it, so it
      # yields both the processor and the disk to whatever is being read.
      nice -n 19 ionice -c 3 \
        xargs -r -d '\n' -n 1 -P "$(nproc)" pdf-find-extract <"$cache/paths" || true

      # Whatever this pass did not touch is a PDF that is no longer there.
      # Keys are hexadecimal, so there is nothing in these names to quote.
      find "$cache/meta" -type f ! -newer "$cache/stamp" -printf '%f\n' \
        | while IFS= read -r stale; do
            rm -f "$cache/meta/$stale" "$cache/text/$stale.txt"
          done

      # Both lists the picker reads are assembled here, with their paths and
      # labels already baked in, so that switching to full-text search is a
      # bare `cat` of a file rather than a walk over the library. The cost is
      # paid once per pass, in the background, instead of once per keystroke.
      : >"$cache/names.new"
      : >"$cache/pages.new"

      records=("$cache"/meta/*)
      if [ -e "''${records[0]}" ]; then
        awk -F'\t' \
          -v cache="$cache" \
          -v home="$HOME" \
          -v namesfile="$cache/names.new" \
          -v pagesfile="$cache/pages.new" '
          FNR == 1 {
            status = $3
            blob = $4
            path = $5
            if (path == "") next

            key = FILENAME
            sub(/.*\//, "", key)

            display = path
            sub("^" home "/", "~/", display)
            cut = length(display)
            while (cut > 0 && substr(display, cut, 1) != "/") cut--
            dir = substr(display, 1, cut)
            base = substr(display, cut + 1)
            tail = length(blob) > 0 ? "  \033[2m" blob "\033[0m" : ""

            printf "%s\t0\t\033[2m%s\033[0m%s%s\n", path, dir, base, tail > namesfile

            if (status != "ok") next

            textfile = cache "/text/" key ".txt"
            while ((getline line < textfile) > 0) {
              tab = index(line, "\t")
              if (tab == 0) continue
              pageno = substr(line, 1, tab - 1)
              body = substr(line, tab + 1)
              if (length(body) == 0) continue
              printf "%s\t%s\t\033[2m%s\033[0m \033[33mp%s\033[0m  %s%s\n", \
                path, pageno, display, pageno, body, tail > pagesfile
            }
            close(textfile)
          }
        ' "''${records[@]}"
      fi

      mv -f "$cache/names.new" "$cache/names"
      mv -f "$cache/pages.new" "$cache/pages"
    '';
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
    text = ''
      set -euo pipefail
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/pdf-find"

      # The cached list goes out first and unconditionally: fzf draws the
      # moment the first line lands, so the window is usable before the scan
      # behind it has looked at a single directory. Anything the scan turns
      # up that the cache has not seen yet arrives without its metadata,
      # which is why the deduplication keeps the first record for a path and
      # not the last. It is awk's rather than `sort -u` because sort has to
      # read the whole stream before it prints anything, which is the one
      # thing this must not do.
      #
      # The scan runs every time, including when the picker is only switching
      # back from full-text search. It costs a few milliseconds against a warm
      # dentry cache, and it means the list is never the empty one a library
      # that has not finished its first pass would otherwise hand back.
      {
        cat "$cache/names" 2>/dev/null || true
        pdf-find-scan | awk -v home="$HOME" '
          {
            display = $0
            sub("^" home "/", "~/", display)
            cut = length(display)
            while (cut > 0 && substr(display, cut, 1) != "/") cut--
            printf "%s\t0\t\033[2m%s\033[0m%s\n", \
              $0, substr(display, 1, cut), substr(display, cut + 1)
          }
        '
      } | awk -F'\t' '!seen[$1]++'
    '';
  };

  pdfFindPages = pkgs.writeShellApplication {
    name = "pdf-find-pages";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      set -euo pipefail
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/pdf-find"
      cat "$cache/pages" 2>/dev/null || true
    '';
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
    text = ''
      set -euo pipefail
      path="''${1:-}"
      page="''${2:-0}"
      query="''${3:-}"
      [ -n "$path" ] || exit 0

      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/pdf-find"
      key=$(printf '%s' "$path" | sha256sum | cut -c1-32)
      record="$cache/meta/$key"
      text="$cache/text/$key.txt"
      width="''${FZF_PREVIEW_COLUMNS:-80}"

      if [ -f "$record" ]; then
        cut -f4 "$record"
        printf '\n'
      fi

      # Never extract from here. Holding an arrow key down over a cold list
      # would fork pdftotext once per repeat; the warm pass will get to it.
      if [ ! -f "$text" ]; then
        printf '(not indexed yet)\n'
        exit 0
      fi

      # A line is a page, so page N is line N -- except in name mode, where
      # there is no page in particular and the opening pages are what say
      # what the document is.
      if [ "$page" = 0 ]; then
        body=$(sed -n '1,3p' "$text")
      else
        body=$(sed -n "''${page}p" "$text")
      fi

      # fzf's operators are part of the query, not of the words being looked
      # for, so they come off before the terms are turned into an alternation.
      read -r -a terms <<<"$query"
      pattern=""
      for term in ''${terms[@]+"''${terms[@]}"}; do
        # A negated term is the reason a page is *not* excluded, so there is
        # nothing in it to point at.
        case "$term" in !*) continue ;; esac
        term=''${term#\'}
        term=''${term#^}
        term=''${term%\$}
        [ -n "$term" ] || continue
        term=$(printf '%s' "$term" | sed 's/[][\\.^$*+?(){}|]/\\&/g')
        if [ -n "$pattern" ]; then pattern="$pattern|$term"; else pattern="$term"; fi
      done

      if [ -n "$pattern" ]; then
        printf '%s\n' "$body" | cut -f2- | fold -s -w "$width" \
          | rg --passthru --color=always --smart-case -e "$pattern" || true
      else
        printf '%s\n' "$body" | cut -f2- | fold -s -w "$width"
      fi
    '';
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
    text = ''
      set -euo pipefail
      file="''${1:-}"
      page="''${2:-0}"
      [ -n "$file" ] || exit 0

      args=(--new-window)
      case "$page" in
        # Name mode has no page in particular, and passing none is the point:
        # sioyek then restores where this document was last left off.
        "" | 0 | *[!0-9]*) ;;
        *) args+=(--page "$page") ;;
      esac

      # `setsid --fork` returns as soon as it has forked and leaves the reader
      # in a session of its own. Since fzf's `become` replaces the picker
      # rather than forking it, that makes this process the terminal's last
      # child -- so the window closes the instant a document is chosen,
      # before sioyek has drawn its own, and takes nothing with it.
      #
      # Detaching the session is not enough on its own: an inherited stdout is
      # still the terminal's pty, and kitty holds its window open until that
      # is closed at both ends. Sioyek would keep it for as long as the
      # document stayed open, printing its startup chatter into a window that
      # was supposed to be gone.
      exec setsid --fork sioyek "''${args[@]}" "$file" \
        </dev/null >/dev/null 2>&1
    '';
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
    text = ''
      set -euo pipefail
      pdf-find-list | fzf \
        --ansi \
        --exact \
        --no-multi \
        --color=16 \
        --info=inline \
        --delimiter=$'\t' \
        --with-nth=3 \
        --prompt='name> ' \
        --header='ctrl-t full text   ctrl-f names   ctrl-/ preview   enter open' \
        --preview='pdf-find-preview {1} {2} {q}' \
        --preview-window='right,55%,wrap,border-left' \
        --bind='ctrl-/:toggle-preview' \
        --bind='ctrl-t:change-prompt(text> )+reload(pdf-find-pages)' \
        --bind='ctrl-f:change-prompt(name> )+reload(pdf-find-list)' \
        --bind='enter:become:pdf-find-open {1} {2}'
    '';
  };

  pdfFind = pkgs.writeShellApplication {
    name = "pdf-find";
    runtimeInputs = with pkgs; [
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
    text = ''
      set -euo pipefail
      setsid --fork pdf-find-warm >/dev/null 2>&1 || true

      exec ${terminal} \
        --class=com.mitchellh.kitty.PdfFind \
        --title="Find PDF" \
        pdf-find-pick
    '';
  };
in
{
  # Sioyek keeps one instance and reopens documents in the window it already
  # has, which is what is wanted from a link or a file manager but not from
  # the picker -- hence --new-window there and the package's own entry here.
  xdg.mimeApps.defaultApplications."application/pdf" = [ "sioyek.desktop" ];

  # Only the entry point goes on PATH under a memorable name; everything else
  # is reached through it and named nowhere but here.
  home.packages = [
    pdfFind
    pkgs.sioyek
  ];

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
  # features/terminal/home.nix, for the same reason: sioyek has an include
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
}
