{ ... }:

# Niri: the compositor session, its helpers, and its configuration.
{
  imports = [ ./system.nix ];
  home-manager.users.jefaturico.imports = [ ./home.nix ];
}
