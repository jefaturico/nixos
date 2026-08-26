{ ... }:

# Local link management behind a closed firewall. Nothing listens: there is
# no SSH server and no tailnet, so no port is ever opened inbound.
{
  networking = {
    networkmanager.enable = true;
    firewall.enable = true;
  };
}
