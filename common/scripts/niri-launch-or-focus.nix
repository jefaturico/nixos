{ pkgs }:
let
  footclient = "$HOME/.local/bin/footclient";
  jq = "${pkgs.jq}/bin/jq";
  niri = "${pkgs.niri}/bin/niri";
in
''
  #!${pkgs.dash}/bin/dash

  if [ "$#" -lt 3 ]; then
      echo "usage: niri-launch-or-focus APP_ID TITLE COMMAND [ARGS...]" >&2
      exit 2
  fi

  APP_ID="$1"
  TITLE="$2"
  shift 2

  WINDOWS_JSON="$(${niri} msg -j windows 2>/dev/null || true)"
  TARGET_ID="$(
      printf '%s\n' "$WINDOWS_JSON" | ${jq} -r --arg app_id "$APP_ID" '
          [
              (.windows? // .)[]
              | select((.app_id // "") == $app_id)
          ]
          | sort_by(.focus_timestamp.secs // 0, .focus_timestamp.nanos // 0)
          | reverse
          | .[0].id // empty
      ' 2>/dev/null
  )"

  if [ -n "$TARGET_ID" ]; then
      exec ${niri} msg action focus-window --id "$TARGET_ID"
  fi

  exec ${footclient} -a "$APP_ID" -T "$TITLE" "$@"
''
