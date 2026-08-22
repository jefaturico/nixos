{ ... }:

# The shared graphical workstation stack.
{
  imports = [ ./system.nix ];
  home-manager.users.jefaturico.imports = [ ./home.nix ];
}
