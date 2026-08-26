{ pkgs, ... }:

# The fonts every program draws from.
{
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    corefonts
  ];
}
