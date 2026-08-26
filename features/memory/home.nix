{ config, pkgs, ... }:

# Spaced repetition, arranged so that the two halves of it stay apart.
#
# Making a card is something that happens mid-thought, so it is a text file
# and an editor and nothing else. Reviewing is its own sitting with nothing
# else in flight, so it is Anki, full stop -- the scheduler is the reason to
# use Anki at all and there is no version of it worth reimplementing here.
#
# What joins them is yanki, which reads `~/documents/notes/cards` and pushes
# it into Anki over AnkiConnect. The directory is the only source of truth:
# one file is one note, and a file's parent directory is its deck, nested as
# deep as the directories go. Nothing is ever authored in Anki's own editor,
# so nothing has to be reconciled back out of it.
let
  cardsDir = "$HOME/documents/notes/cards";
  terminal = "${config.programs.kitty.package}/bin/kitty";
  editor = "${config.programs.neovim.finalPackage}/bin/nvim";

  yanki = pkgs.callPackage ./package.nix { nodejs = pkgs.nodejs_22; };

  # withAddons is what makes AnkiConnect part of the package rather than
  # something installed by hand through Anki's add-on dialog. It has to be
  # this derivation everywhere: `pkgs.anki` is a different, add-on-less build,
  # and putting that one on cards-study's PATH would shadow this one and
  # launch an Anki with no port for the sync to talk to.
  ankiWithAddons = pkgs.anki.withAddons [ pkgs.ankiAddons.anki-connect ];

  # One definition of "push the directory into Anki", called from the editor's
  # BufWritePost and from cards-study, so a card written while Anki was closed
  # still arrives the next time review starts.
  #
  # --anki-web is off because there is no AnkiWeb account to push to; left at
  # its default the sync would end by failing against a service that was never
  # signed into.
  #
  # --manage-filenames is what makes the placeholder name cards-new invents
  # disposable: after a sync each file is named after the front of its own
  # card. It is off by default because it renames files on disk, and doing
  # that to a file open in an editor leaves the buffer pointing at a path that
  # no longer exists -- the next :w would write the old name back and Anki
  # would gain a second copy of the card. So --rename is opt-in, asked for
  # only by the callers that run with no editor attached to the directory.
  cardsSync = pkgs.writeShellApplication {
    name = "cards-sync";
    runtimeInputs = [ yanki ];
    text = ''
      set -euo pipefail
      dir="${cardsDir}"
      [ -d "$dir" ] || exit 0

      rename=off
      if [ "''${1:-}" = "--rename" ]; then
        rename=prompt
      fi

      exec yanki sync "$dir" \
        --manage-filenames "$rename" \
        --sync-media local \
        --anki-web false
    '';
  };

  # The picker half of cards-new, run inside the terminal the window rule
  # matches. It ends by handing that same window to Neovim rather than
  # spawning a second one: the target here is a text file, so the window the
  # picker was already using is the window the editor wants.
  cardsNewPick = pkgs.writeShellApplication {
    name = "cards-new-pick";
    runtimeInputs = with pkgs; [
      coreutils
      fd
      findutils
      fzf
      cardsSync
    ];
    # The header carries the syntax because this is the last thing on screen
    # before the file is empty and waiting. It is three rules and they are
    # only needed until they are known, which is exactly what a header is
    # good for -- unlike a skeleton written into the file, which would cost a
    # cursor move on every card forever in order to type past it.
    text = ''
      set -euo pipefail
      dir="${cardsDir}"
      mkdir -p "$dir"

      # A deck directory with nothing in it is always the residue of a card
      # that was started and abandoned, since a deck is only ever created in
      # order to put a card in it. Pruning here rather than on the way out
      # means it happens however the last run ended, including the one way it
      # cannot clean up after itself: closing the window kills the script.
      find "$dir" -mindepth 1 -type d -empty -delete

      new='+ new deck'
      choice=$(
        {
          printf '%s\n' "$new"
          fd --type d --base-directory "$dir" | sed 's:/$::' | sort
        } | fzf \
          --exact \
          --no-multi \
          --color=16 \
          --info=inline \
          --prompt='deck> ' \
          --header='front --- back    ~~cloze~~    _type in the answer_'
      )

      if [ "$choice" = "$new" ]; then
        read -r -p 'new deck: ' choice
      fi

      # Empty covers both dismissing fzf and answering the prompt with
      # nothing; the leading-slash and dot-dot cases are the ways a deck name
      # could otherwise name somewhere outside the cards directory.
      case "$choice" in
        "" | /* | *..*) exit 0 ;;
      esac

      deck="$dir/$choice"
      mkdir -p "$deck"

      # A placeholder name only has to be unique until the next sync renames
      # it. Seconds are enough: two cards cannot be started in the same one.
      #
      # The file is deliberately not created here. Neovim writes it on the
      # first :w and not before, so a card that is never typed into leaves
      # nothing on disk at all -- which is the only version of this that
      # survives the window being closed rather than the editor being quit.
      file="$deck/$(date '+%Y%m%d%H%M%S').md"

      ${editor} -c startinsert "$file"

      # Nothing was typed, so nothing is left behind -- neither the empty
      # file nor the deck directory if this card was the reason it existed.
      if [ ! -f "$file" ] || ! grep -q '[^[:space:]]' "$file"; then
        rm -f "$file"
        rmdir --ignore-fail-on-non-empty "$deck" 2>/dev/null || true
        exit 0
      fi

      cards-sync --rename >/dev/null 2>&1 || true
    '';
  };

  cardsNew = pkgs.writeShellApplication {
    name = "cards-new";
    runtimeInputs = [ cardsNewPick ];
    # --class is how the niri window rule finds this window and has to precede
    # the command, the same way pdf-find spells it in features/documents.
    text = ''
      set -euo pipefail
      exec ${terminal} \
        --class=com.mitchellh.kitty.CardNew \
        --title="New card" \
        cards-new-pick
    '';
  };

  # AnkiConnect lives inside Anki, so a sync can only land while Anki is up.
  # That decides the order here: raise or start Anki first, wait for the port
  # to answer, and only then push. Anki is single-instance, so the launch is
  # also how an already-running window is brought forward.
  cardsStudy = pkgs.writeShellApplication {
    name = "cards-study";
    runtimeInputs = [
      ankiWithAddons
      cardsSync
      pkgs.coreutils
      pkgs.curl
      pkgs.libnotify
    ];
    text = ''
      set -euo pipefail
      anki >/dev/null 2>&1 &

      for _ in $(seq 60); do
        if curl -fsS -m 1 -d '{"action":"version","version":6}' \
          http://127.0.0.1:8765 >/dev/null 2>&1; then
          cards-sync --rename >/dev/null 2>&1 || true
          exit 0
        fi
        sleep 0.5
      done

      # Anki opens either way, so the review still happens -- what is worth
      # saying is that it opened holding whatever it already had. There is no
      # status bar to notice a missing sync in, so it is said out loud.
      notify-send "Anki" "AnkiConnect never answered; cards were not synced."
    '';
  };
in
{
  # Anki's preferences are left to Anki: it is a stateful application that
  # writes its own profile, and its appearance already follows the portal
  # setting `desktop-theme` drives, so there is nothing here to declare.
  home.packages = [
    ankiWithAddons
    cardsNew
    cardsStudy
    cardsSync
    yanki
  ];
}
