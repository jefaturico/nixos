{ ... }:

# The ssh client. The GitHub key has a non-default filename, so nothing
# offers it unless this file names it; the key itself is a plain file in
# ~/.ssh, placed by hand and tracked nowhere.
{
  home-manager.users.jefaturico.programs.ssh = {
    enable = true;
    matchBlocks."github.com" = {
      user = "git";
      identityFile = "~/.ssh/id_tethys-github";
      identitiesOnly = true;
    };
  };
}
