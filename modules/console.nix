{ pkgs, ... }:
{
  # Keyboard layout, shared by the console and (through home/hyprland.nix)
  # the desktop. Was KEYMAP=us-altgr-intl in /etc/vconsole.conf.
  services.xserver.xkb = {
    layout = "us";
    variant = "altgr-intl";
  };

  console = {
    # Terminus 11x22 bold. Was FONT=ter-122b in /etc/vconsole.conf.
    font = "ter-122b";
    packages = [ pkgs.terminus_font ];
    useXkbConfig = true;
    # Font and colours (from stylix) already in the initrd.
    earlySetup = true;
  };
}
