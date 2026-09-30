{ ... }:
{
  # Was ~/.bashrc
  programs.bash = {
    enable = true;
    shellAliases = {
      ls = "ls --color=auto";
      grep = "grep --color=auto";
      vi = "nvim";
      vim = "nvim";
    };
    initExtra = ''
      PS1='\[\e[36m\]\w\[\e[0m\] \[\e[32m\]λ\[\e[0m\] '
    '';
  };

  home.sessionPath = [ "$HOME/.scripts" ];

  # Was ~/.config/environment.d/10-editor.conf. Set for the shell and for
  # everything systemd starts in the session.
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
  systemd.user.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # Was ~/.gitconfig
  programs.git = {
    enable = true;
    settings.user = {
      name = "jefaturico";
      email = "jefaturico@gmail.com";
    };
  };

  # Was ~/.ssh/config. The key itself is not managed, make a new one:
  #   ssh-keygen -t ed25519 -f ~/.ssh/id_coriolis-github
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."github.com" = {
      HostName = "github.com";
      User = "git";
      IdentityFile = "~/.ssh/id_coriolis-github";
      IdentitiesOnly = true;
    };
  };

  # New, from the backburner list. With a `use flake` line in a project's
  # .envrc, cd'ing into it loads its dev shell, cached.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # nix-index (also from the backburner list) is set up system-wide in
  # modules/nix.nix.
}
