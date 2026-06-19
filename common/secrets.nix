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

    secrets =
      {
        "ssh-id-tailnet" = {
          path = "/home/jefaturico/.ssh/id_tailnet";
          owner = "jefaturico";
          group = "users";
          mode = "0600";
        };
      }
      // lib.optionalAttrs (hostName == "galileo") {
        "ssh-galileo-github" = {
          path = "/home/jefaturico/.ssh/id_galileo-github";
          owner = "jefaturico";
          group = "users";
          mode = "0600";
        };
      }
      // lib.optionalAttrs (hostName == "ekman") {
        "ssh-ekman-github" = {
          path = "/home/jefaturico/.ssh/id_ekman-github";
          owner = "jefaturico";
          group = "users";
          mode = "0600";
        };
      };
  };
}
