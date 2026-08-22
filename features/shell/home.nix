{ pkgs, ... }:

# The interactive shell: prompt, history, navigation, and the small helpers
# that only make sense at a prompt.
{
  programs.fzf.enable = true;

  programs.bash = {
    enable = true;
    # bash-completion adds measurable startup latency and is not worth it for
    # this workflow; readline's own case-insensitive completion is enough.
    enableCompletion = false;

    shellAliases.o = "xdg-open";

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    initExtra = ''
      export FZF_DEFAULT_OPTS="--color=bg:-1,bg+:-1,gutter:-1"

      # Jump to a device mounted by udiskie under /run/media/$USER.
      usb() {
        local media_root target
        media_root="/run/media/''${USER:-$(${pkgs.coreutils}/bin/id -un)}"

        _usb_mounts() {
          [[ -d "$media_root" ]] || return 0
          ${pkgs.findutils}/bin/find "$media_root" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -printf '%T@\t%p\n' 2>/dev/null \
            | ${pkgs.coreutils}/bin/sort -rn \
            | ${pkgs.coreutils}/bin/cut -f2-
        }

        case "''${1:-}" in
          -l|--list)
            target="$(_usb_mounts | ${pkgs.fzf}/bin/fzf --prompt='USB: ' --no-sort)" || return "$?"
            ;;
          -h|--help)
            printf '%s\n\n%s\n%s\n' \
              'Usage: usb [-l]' \
              '  usb     cd to the most recently mounted removable device and list it' \
              '  usb -l  choose a mounted removable device with fzf, cd to it, and list it'
            return 0
            ;;
          "")
            target="$(_usb_mounts | ${pkgs.coreutils}/bin/head -n 1)"
            ;;
          *)
            printf 'usb: unknown option: %s\n' "$1" >&2
            return 2
            ;;
        esac

        if [[ -z "$target" ]]; then
          printf 'usb: no mounted removable devices found under /run/media/%s\n' "$USER" >&2
          return 1
        fi

        cd "$target" && ls
      }

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

      # Keep graphical terminal titles useful to window selectors: show the
      # foreground command while it runs and the working directory at the
      # prompt. Applications can override this with a richer title of their
      # own.
      if [[ $TERM != linux && $TERM != dumb ]]; then
        _terminal_set_title() {
          printf '\e]0;%s\e\\' "$1"
        }

        _terminal_preexec() {
          local command="''${1#"''${1%%[![:space:]]*}"}"
          local program="''${command%%[[:space:]]*}"
          program="''${program##*/}"
          [[ -n $program ]] && _terminal_set_title "$program"
        }

        _terminal_prompt_end() {
          local command_status=$?
          _terminal_set_title "''${PWD/#$HOME/~}"

          return "$command_status"
        }

        trap '_terminal_preexec "$BASH_COMMAND"' DEBUG
        PROMPT_COMMAND+=(_terminal_prompt_end)
      fi
    '';
  };

  home.packages = [ pkgs.zoxide ];
}
