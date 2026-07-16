{ pkgs, ... }:
{
  # Small recovery/SSH baseline shared by desktops and the headless server.
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    htop
    rsync
  ];

  programs.bash.interactiveShellInit = ''
    nix() {
      command nix --log-format bar-with-logs --print-build-logs "$@"
    }

    nixos-rebuild() {
      command nixos-rebuild --log-format bar-with-logs --print-build-logs "$@"
    }
  '';
}
