{ ... }:

# The single human account. Only the machine-independent parts live here;
# modules that need extra group membership (the desktop stack needs `video`,
# `render`, and `input`) append to `extraGroups` themselves, and hosts append
# any additional authorized key they accept.
{
  users.users.jefaturico = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    openssh.authorizedKeys.keys = [
      # Tailnet identity, materialized on every host by sops-nix.
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfx6y39zNZYSLw18oOwuX8N+aStamNANfZJtCrBEK3I tailnet"
    ];
  };
}
