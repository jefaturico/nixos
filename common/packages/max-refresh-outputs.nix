{ pkgs }:

pkgs.writeShellApplication {
  name = "max-refresh-outputs";
  runtimeInputs = with pkgs; [
    coreutils
    jq
    wlr-randr
  ];
  text = ''
    set -u

    # River uses each display's EDID "preferred" mode by default. Some high
    # refresh monitors incorrectly mark a 60 Hz mode as preferred, so select
    # the best advertised mode ourselves: pixel count first, refresh last.
    # Deliberately leave adaptive sync untouched; refresh rate and VRR are
    # independent output properties.
    failures=0
    while [ "$failures" -lt 5 ]; do
      if outputs=$(wlr-randr --json 2>/dev/null); then
        failures=0
        args=()

        while IFS= read -r output; do
          name=$(jq -r '.name' <<<"$output")
          mode=$(jq -r '.mode' <<<"$output")
          args+=(--output "$name" --mode "$mode")
        done < <(
          jq -c '
            .[]
            | select(.enabled == true)
            | (.modes | max_by([(.width * .height), .width, .height, .refresh])) as $best
            | select($best.current != true)
            | {
                name,
                mode: ($best.width | tostring)
                  + "x" + ($best.height | tostring)
                  + "@" + ($best.refresh | tostring) + "Hz"
              }
          ' <<<"$outputs"
        )

        if [ "''${#args[@]}" -gt 0 ]; then
          # A connector can disappear between the query and the atomic apply.
          # Treat that as a transient hotplug race and retry on the next pass.
          wlr-randr "''${args[@]}" >/dev/null 2>&1 || true
        fi
      else
        failures=$((failures + 1))
      fi

      sleep 2
    done
  '';
}
