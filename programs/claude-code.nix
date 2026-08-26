{ ... }:

# Claude Code, from the stable release.
{
  home-manager.users.jefaturico =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.claude-code ];
    };
}
