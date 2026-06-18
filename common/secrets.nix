{ config, lib, ... }:

let
  isGalileo = config.networking.hostName == "galileo";
in
{
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    age = {
      sshKeyPaths = [
        "/etc/ssh/ssh_host_ed25519_key"
        "/home/jefaturico/.ssh/galileo-github"
      ];
    };

    secrets = {
      "ssh-galileo-github" = {
        path = "/home/jefaturico/.ssh/galileo-github";
        owner = "jefaturico";
        group = "users";
        mode = "0600";
      };

      "ssh-id-tailnet" = {
        path = "/home/jefaturico/.ssh/id_tailnet";
        owner = "jefaturico";
        group = "users";
        mode = "0600";
      };

      "vdirsyncer-google-calendar.env" = lib.mkIf isGalileo {
        owner = "jefaturico";
        group = "users";
        mode = "0400";
      };
    };
  };
}
