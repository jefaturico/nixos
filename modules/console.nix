{ pkgs, ... }:
{
  # Keyboard layout, shared by the console and (through niri's own config)
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
    # Font and colours already in the initrd, so the LUKS prompt has them.
    earlySetup = true;

    # Gruvbox palette. Was /etc/vtrgb + vtrgb.service.
    colors = [
      "282828"
      "cc241d"
      "98971a"
      "d79921"
      "458588"
      "b16286"
      "689d6a"
      "ebdbb2"
      "928374"
      "fb4934"
      "b8bb26"
      "fabd2f"
      "83a598"
      "d3869b"
      "8ec07c"
      "fbf1c7"
    ];
  };
}
