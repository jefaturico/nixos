{ config, lib, ... }:

let
  sharedAllowedPackages = [
    "antigravity"
    "brave"
    "code"
    "nvidia-x11"
    "nvidia-kernel-modules"
    "nvidia-settings"
    "vscode"
    "vscode-fhs"
    "corefonts"
  ];
in
{
  options.jefaturico.allowedUnfreePackages = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = sharedAllowedPackages;
    description = ''
      Nixpkgs package names allowed by the shared unfree predicate.
      Hosts can extend this with lib.mkAfter when they need additional unfree packages.
    '';
  };

  config.nixpkgs.config = {
    allowUnfree = false;
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) config.jefaturico.allowedUnfreePackages;
  };
}
