{ ... }:

# Removable media: udisks2 exposes the devices and udiskie (session-scoped,
# through Home Manager) mounts them.
{
  services.udisks2.enable = true;

  home-manager.users.jefaturico.services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "never";
  };
}
