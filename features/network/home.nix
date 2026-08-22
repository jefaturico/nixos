{
  lib,
  osConfig,
  ...
}:

# SSH client policy. Every host reaches its peers over the tailnet with one
# shared identity and reaches GitHub with an identity named after itself, so
# a compromised machine can be revoked individually.
let
  hostName = osConfig.networking.hostName;

  peerHost =
    if hostName == "titan" then
      "tethys"
    else if hostName == "tethys" then
      "titan"
    else
      null;

  tailnetHost = {
    User = "jefaturico";
    IdentityFile = "~/.ssh/id_tailnet";
    IdentitiesOnly = true;
  };
in
{
  programs.ssh = {
    enable = true;
    # Home Manager's stock `*` block enables agent forwarding, multiplexing,
    # and keepalives. None of them are wanted here, so start from nothing.
    enableDefaultConfig = false;

    settings = {
      "github.com" = {
        HostName = "github.com";
        User = "jefaturico";
        IdentityFile = "~/.ssh/id_${hostName}-github";
      };

      "*" = {
        ForwardAgent = false;
        AddKeysToAgent = "no";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };
    }
    // lib.optionalAttrs (peerHost != null) {
      ${peerHost} = tailnetHost;
      iapetus = tailnetHost;
    };
  };
}
