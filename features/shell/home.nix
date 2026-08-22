{ pkgs, ... }:

# The interactive shell: prompt, history, and navigation.
{
  programs.fzf.enable = true;

  programs.bash = {
    enable = true;
    # bash-completion adds measurable startup latency and is not worth it for
    # this workflow; readline's own case-insensitive completion is enough.
    enableCompletion = false;

    shellAliases = {
      o = "xdg-open";
      rebuild = "sudo nixos-rebuild switch --flake path:$HOME/nixos#tethys --log-format bar-with-logs --print-build-logs";
    };

    initExtra = ''
      bind "set completion-ignore-case on"

      shopt -s autocd     # 'cd' is optional for directories
      shopt -s cdspell    # fix minor typos in 'cd'
      shopt -s checkwinsize
      shopt -s cmdhist
      shopt -s dirspell
      shopt -s globstar   # recursive globbing (**/*.nix)
      shopt -s histappend

      HISTCONTROL=ignoreboth:erasedups
      HISTSIZE=10000
      HISTFILESIZE=20000

      eval "$(${pkgs.zoxide}/bin/zoxide init bash --cmd cd)"
    '';
  };

  home.packages = [ pkgs.zoxide ];
}
