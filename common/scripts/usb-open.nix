{ pkgs }:
''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail

  media_root="/run/media/''${USER:-$(${pkgs.coreutils}/bin/id -un)}"

  if [ ! -d "$media_root" ]; then
      ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status "USB" "No mounted removable devices"
      exit 0
  fi

  mounts="$(
      ${pkgs.findutils}/bin/find "$media_root" \
          -mindepth 1 \
          -maxdepth 1 \
          -type d \
          -printf '%T@\t%p\n' 2>/dev/null \
          | ${pkgs.coreutils}/bin/sort -rn \
          | ${pkgs.coreutils}/bin/cut -f2-
  )"

  if [ -z "$mounts" ]; then
      ${pkgs.libnotify}/bin/notify-send -h string:x-canonical-private-synchronous:status "USB" "No mounted removable devices"
      exit 0
  fi

  target="$(printf '%s\n' "$mounts" | ${pkgs.fuzzel}/bin/fuzzel -d --no-sort -p 'USB: ' -w 70 || true)"

  if [ -z "$target" ]; then
      exit 0
  fi

  exec footclient -D "$target"
''
