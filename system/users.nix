{ ... }:

# The single human account. Modules that need extra group membership append
# to `extraGroups` themselves, so removing a module removes what it added.
{
  users.users.jefaturico = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      # Direct hardware access for the graphical session.
      "video"
      "render"
      "input"
    ];
  };
}
