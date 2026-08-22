{ config, ... }:

# Everything that decides how this machine is reachable: local link
# management, the firewall boundary, the tailnet, and the SSH server.
{
  networking = {
    networkmanager.enable = true;
    firewall = {
      enable = true;
      # Tailscale is the only trusted transport; SSH is never exposed to a
      # physical network.
      trustedInterfaces = [ "tailscale0" ];
    };
  };

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "client";
    extraSetFlags = [ "--hostname=${config.networking.hostName}" ];
  };
}
