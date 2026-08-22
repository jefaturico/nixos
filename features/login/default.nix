{ ... }:

# Getting from power-on to an authenticated session, and back after locking.
{
  imports = [ ./system.nix ];
  home-manager.users.jefaturico.imports = [ ./home.nix ];
}
