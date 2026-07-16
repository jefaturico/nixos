{ config, lib, ... }:

let
  hostName = config.networking.hostName;
in
{
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    age = {
      sshKeyPaths = [
        "/etc/ssh/ssh_host_ed25519_key"
      ];
    };

    secrets = {
      "ssh-id-tailnet" = {
        path = "/home/jefaturico/.ssh/id_tailnet";
        owner = "jefaturico";
        group = "users";
        mode = "0600";
      };
    }
    // lib.optionalAttrs (hostName == "titan") {
      "ssh-titan-github" = {
        key = "ssh-galileo-github";
        path = "/home/jefaturico/.ssh/id_titan-github";
        owner = "jefaturico";
        group = "users";
        mode = "0600";
      };
    }
    // lib.optionalAttrs (hostName == "tethys") {
      "ssh-tethys-github" = {
        key = "ssh-ekman-github";
        path = "/home/jefaturico/.ssh/id_tethys-github";
        owner = "jefaturico";
        group = "users";
        mode = "0600";
      };
    };
  };
}
