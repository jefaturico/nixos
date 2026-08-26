{ ... }:

# Version control identity and defaults.
{
  home-manager.users.jefaturico.programs.git = {
    enable = true;
    settings = {
      user.name = "jefaturico";
      user.email = "jefaturico@gmail.com";
      init.defaultBranch = "main";
    };
  };
}
