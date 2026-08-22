{ ... }:

# How this machine is reached, and how it reaches its peers.
{
  imports = [ ./system.nix ];
  home-manager.users.jefaturico.imports = [ ./home.nix ];
}
