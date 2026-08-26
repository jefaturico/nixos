{ ... }:

# Frecency-ranked directory jumping, installed over `cd` itself.
{
  home-manager.users.jefaturico.programs.zoxide = {
    enable = true;
    options = [
      "--cmd"
      "cd"
    ];
  };
}
