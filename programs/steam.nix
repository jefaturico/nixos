{ ... }:

# The ordinary NixOS Steam client: no replacement launcher, nested
# compositor, per-game wrapper, or separate login session. It also pulls in
# the 32-bit graphics stack that Proton and Wine titles need.
{
  programs.steam.enable = true;
}
