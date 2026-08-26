set -euo pipefail

# The theme entry names the theme it switches *to*, so the label has to
# be computed rather than listed, and matched back the same way.
if [ "$(desktop-theme)" = dark ]; then
  theme_entry='Switch to light theme'
else
  theme_entry='Switch to dark theme'
fi

choice=$(printf '%s\n' Lock Network "$theme_entry" Suspend Hibernate \
  'Exit session' Reboot 'Power off' \
  | fuzzel --dmenu --prompt='Power: ' --lines=8 --minimal-lines) || exit 0
case "$choice" in
  Lock) exec waylock -fork-on-lock ;;
  Network) exec desktop-network ;;
  "$theme_entry") exec desktop-theme toggle ;;
  Suspend) exec systemctl suspend ;;
  Hibernate) exec systemctl hibernate ;;
  'Exit session') exec niri msg action quit --skip-confirmation ;;
  Reboot) exec systemctl reboot ;;
  'Power off') exec systemctl poweroff ;;
esac
