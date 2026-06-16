{ pkgs }:
let
  fuzzel = "${pkgs.fuzzel}/bin/fuzzel";
  jq = "${pkgs.jq}/bin/jq";
  niri = "${pkgs.niri}/bin/niri";
  notifySend = "${pkgs.libnotify}/bin/notify-send";
in
''
  #!${pkgs.dash}/bin/dash

  notify() {
      ${notifySend} -h string:x-canonical-private-synchronous:status "Window Switcher" "$1"
  }

  WINDOWS_JSON="$(${niri} msg -j windows 2>/dev/null)"
  if [ -z "$WINDOWS_JSON" ]; then
      notify "Could not read niri windows"
      exit 1
  fi

  ENTRIES="$(printf '%s\n' "$WINDOWS_JSON" | ${jq} -r '
      def clean:
          tostring
          | gsub("[\t\r\n]+"; " ")
          | gsub("^ +| +$"; "");

      (.windows? // .)[]
      | (.workspace_id // "?" | tostring) as $workspace
      | (.app_id // "?" | clean) as $app
      | ((.title // "Untitled") | clean) as $title
      | "\(.id)\t[\($workspace)] \($app): \($title)"
  ')"

  if [ -z "$ENTRIES" ]; then
      notify "No open windows"
      exit 0
  fi

  TARGET_ID="$(printf '%s\n' "$ENTRIES" | ${fuzzel} -d --no-sort --with-nth=2 --match-nth=2 --accept-nth=1 -p "Focus a window: " -w 80 || true)"
  if [ -z "$TARGET_ID" ]; then
      exit 0
  fi

  ${niri} msg action focus-window --id "$TARGET_ID"
''
