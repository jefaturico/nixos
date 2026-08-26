set -euo pipefail

dir="${XDG_PICTURES_DIR:-$HOME/pictures}/wallpapers"
shopt -s nullglob
images=("$dir"/*)
shopt -u nullglob

if [ "${#images[@]}" -ne 1 ]; then
  echo "desktop-wallpaper: expected exactly one image in $dir, found ${#images[@]}" >&2
  exit 1
fi

exec wbg "${images[0]}"
