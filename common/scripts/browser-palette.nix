{ pkgs }:
let
  awk = "${pkgs.gawk}/bin/awk";
  curl = "${pkgs.curl}/bin/curl";
  fuzzel = "${pkgs.fuzzel}/bin/fuzzel";
  jq = "${pkgs.jq}/bin/jq";
  niri = "${pkgs.niri}/bin/niri";
  notifySend = "${pkgs.libnotify}/bin/notify-send";
in
''
  #!${pkgs.bash}/bin/bash

  BOOKMARK_FILE="$HOME/nixos/common/bookmarks.txt"

  notify() {
      ${notifySend} -h string:x-canonical-private-synchronous:browser "Browser" "$1"
  }

  focus_window() {
      ${niri} msg action focus-window --id "$1"
  }

  open_url() {
      setsid chromium-app "$1" >/dev/null 2>&1 &
  }

  WINDOWS_JSON="$(${niri} msg -j windows 2>/dev/null)"
  if [ -z "$WINDOWS_JSON" ]; then
      notify "Could not read niri windows"
      exit 1
  fi

  WINDOWS="$(printf '%s\n' "$WINDOWS_JSON" | ${jq} -r '
      def clean:
          tostring
          | gsub("[\t\r\n]+"; " ")
          | gsub("^ +| +$"; "");

      def browser_app_id:
          . == "chromium" or
          . == "chromium-browser" or
          . == "ungoogled-chromium" or
          . == "chromium-app" or
          startswith("chrome-");

      [
          (.windows? // .)[]
          | select((.app_id // "") | browser_app_id)
      ]
      | sort_by(.focus_timestamp.secs // 0, .focus_timestamp.nanos // 0)
      | reverse
      | .[]
      | ((.title // "Untitled") | clean) as $title
      | "\(.id)\t\($title)"
  ')"

  OPEN_URLS="$(
      ${curl} -fsS --max-time 0.2 http://127.0.0.1:9222/json/list 2>/dev/null \
          | ${jq} -r '
              .[]?
              | select((.type // "") == "page")
              | (.url // "")
              | select(. != "")
          ' 2>/dev/null || true
  )"

  ENTRIES="$(
      {
          printf '%s\n' "$WINDOWS" | ${awk} -F '\t' '
              NF >= 2 && $1 != "" {
                  print "window" "\t" $1 "\t" $2
              }
          '

          printf '%s\n' "$OPEN_URLS" | ${awk} '
              NF > 0 {
                  print "openurl" "\t" $0 "\t" $0
              }
          '

          if [ -f "$BOOKMARK_FILE" ]; then
              ${awk} '
          NF >= 2 {
              url=$NF
              label=$0
              sub(/[[:space:]][^[:space:]]+$/, "", label)
              gsub(/[\t\r\n]+/, " ", label)
              gsub(/^ +| +$/, "", label)
              print "bookmark" "\t" url "\t" label
          }
      ' "$BOOKMARK_FILE"
          fi
      } | ${awk} -F '\t' '
          function host_from_url(url,    host) {
              host = url
              sub(/^[^:]+:\/\//, "", host)
              sub(/\/.*/, "", host)
              sub(/:.*/, "", host)
              sub(/^www\./, "", host)
              return tolower(host)
          }

          function host_present(title, host,    host_with_www) {
              host_with_www = "www." host
              return title == host ||
                  index(title, " " host) > 0 ||
                  index(title, " - " host) > 0 ||
                  index(title, " | " host) > 0 ||
                  index(title, "[" host "]") > 0 ||
                  index(title, " " host_with_www) > 0 ||
                  index(title, " - " host_with_www) > 0 ||
                  index(title, " | " host_with_www) > 0 ||
                  index(title, "[" host_with_www "]") > 0
          }

          function matching_window_open(host,    i) {
              if (host in open_hosts || ("www." host) in open_hosts) {
                  return 1
              }
              for (i = 1; i <= title_count; i++) {
                  if (host_present(titles[i], host)) {
                      return 1
                  }
              }
              return 0
          }

          $1 == "window" && NF >= 3 {
              titles[++title_count] = tolower($3)
              labels[++entry_count] = "Window: " $3
              rows[entry_count] = "window" "\t" $2 "\t" labels[entry_count]
              counts[labels[entry_count]]++
              next
          }

          $1 == "openurl" && NF >= 2 {
              host = host_from_url($2)
              if (host != "") {
                  open_hosts[host] = 1
              }
              next
          }

          $1 == "bookmark" && NF >= 3 {
              host = host_from_url($2)
              if (host == "" || !matching_window_open(host)) {
                  labels[++entry_count] = "Bookmark: " $3
                  rows[entry_count] = "bookmark" "\t" $2 "\t" labels[entry_count]
                  counts[labels[entry_count]]++
              }
              next
          }

          END {
              for (i = 1; i <= entry_count; i++) {
                  suffix = ""
                  if (counts[labels[i]] > 1) {
                      seen[labels[i]]++
                      suffix = " (" seen[labels[i]] ")"
                  }
                  print rows[i] suffix
              }
          }
      '
  )"

  SELECTED="$(printf '%s\n' "$ENTRIES" | ${fuzzel} -d --no-sort --match-mode=exact --with-nth=3 --match-nth=3 -p "Browser: " -w 80 || true)"
  if [ -z "$SELECTED" ]; then
      exit 0
  fi

  IFS=$'\t' read -r ACTION TARGET LABEL <<< "$SELECTED"

  case "$ACTION" in
      window)
          focus_window "$TARGET"
          ;;
      bookmark)
          open_url "$TARGET"
          ;;
      *)
          open_url "$SELECTED"
          ;;
  esac
''
