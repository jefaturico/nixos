{
  config,
  lib,
  pkgs,
  ...
}:

let
  hostName = config.networking.hostName;
in
{
  # Editing `secrets/secrets.yaml` in place needs the CLI, and enrolling a new
  # host needs its age recipient derived from the SSH host key.
  environment.systemPackages = with pkgs; [
    sops
    ssh-to-age
  ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    age = {
      sshKeyPaths = [
        "/etc/ssh/ssh_host_ed25519_key"
        "/home/jefaturico/.ssh/id_tailnet"
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
