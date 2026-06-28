{ config, lib, ... }:
{
  options.jefaturico.allowedUnfreePackages = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Nixpkgs package names allowed by the shared unfree predicate.";
  };

  config.nixpkgs.config = {
    allowUnfree = false;
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) config.jefaturico.allowedUnfreePackages;
  };
}
