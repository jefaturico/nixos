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
      rebuild = "sudo nixos-rebuild switch --flake path:$HOME/nixos#tethys";
    };

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    initExtra = ''
      export FZF_DEFAULT_OPTS="--color=bg:-1,bg+:-1,gutter:-1"

      bind "set completion-ignore-case on"

      if [[ -n "$WAYLAND_DISPLAY" || -n "$DISPLAY" ]]; then
        _prompt_char="λ"
      else
        _prompt_char="\$"
      fi
      PS1='\[\e[34m\]\w\[\e[0m\] \[\e[32m\]'"$_prompt_char"'\[\e[0m\] '

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
