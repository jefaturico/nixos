{ ... }:

# Emacs, stock. Nothing is configured here beyond the font, and nothing else
# in this repository contributes to it. Everything gets added back one piece
# at a time, deliberately, or not at all.
{
  home-manager.users.jefaturico.imports = [ ./home.nix ];
}
