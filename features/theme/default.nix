{ ... }:

# The system-wide light/dark switch. The applications themselves are themed
# by their own features; this one owns the decision and the plumbing that
# distributes it.
{
  imports = [ ./system.nix ];
  home-manager.users.jefaturico.imports = [ ./home.nix ];
}
