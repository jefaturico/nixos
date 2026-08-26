{ pkgs, ... }:

# Calcurse. Mod+C opens it; a background daemon notifies ahead of timed
# appointments whether or not the interface is running.
let
  # Calcurse hands the notification command no arguments: the command is
  # expected to ask for the appointment itself, which is what `--next` is
  # for. Its first line is the words "next appointment:", so it is dropped
  # and what is left is `[00:15] Analysis lecture` -- a countdown rather than
  # a clock time, which is the more useful of the two in a popup.
  calcurseNotify = pkgs.writeShellApplication {
    name = "calcurse-notify";
    runtimeInputs = with pkgs; [
      calcurse
      coreutils
      gnused
      libnotify
    ];
    text = builtins.readFile ../../scripts/calcurse-notify.sh;
  };

  # The daemon is stopped through its pid file rather than by systemd killing
  # the control group, for the reason spelled out at the unit below: the
  # running daemon is often not the one systemd started. This is a script
  # rather than an inline `ExecStop` because systemd expands `$` in a command
  # line itself, so a shell variable written there never reaches the shell.
  calcurseDaemonStop = pkgs.writeShellApplication {
    name = "calcurse-daemon-stop";
    runtimeInputs = with pkgs; [ coreutils ];
    text = builtins.readFile ../../scripts/calcurse-daemon-stop.sh;
  };

  # Written once and then left alone, because calcurse saves this file itself
  # whenever the Notify menu is used. A symlink into the store would be read
  # only and every settings change made from inside the interface would fail
  # to save, so the file is seeded and handed over.
  #
  # `notifyall=all` is the setting that matters: calcurse's default is to
  # notify only for appointments flagged important by hand, which would mean
  # remembering to press `!` on every entry. With `all` the warning applies
  # to every timed appointment and there is nothing per-event to do.
  #
  # The command is named rather than given a store path for the same reason
  # the file is not managed: this file outlives the generation that wrote it,
  # and an absolute store path in it would break the first time the garbage
  # collector ran.
  seed = pkgs.writeText "calcurse-conf" ''
    daemon.enable=yes
    notification.warning=1800
    notification.notifyall=all
    notification.command=calcurse-notify
  '';
in
{
  home.packages = with pkgs; [
    calcurse
    calcurseNotify
  ];

  home.activation.calcurseConf = ''
    conf="''${XDG_CONFIG_HOME:-$HOME/.config}/calcurse/conf"
    if [ ! -e "$conf" ]; then
      run mkdir -p "$(dirname "$conf")"
      run install -m 644 ${seed} "$conf"
    fi
  '';

  # Calcurse manages this process itself once it is up: opening the interface
  # stops the daemon, and quitting the interface starts a new one, because
  # `daemon.enable` is set. So this unit exists only to get the first one
  # running at login -- hence oneshot, and no `Restart`, which would fight
  # the interface for ownership every time the calendar was opened.
  #
  # The consequence is that the daemon systemd stops at the end of a session
  # may not be the one it started, and would not be in this unit's control
  # group to be killed with it. `ExecStop` therefore goes through the pid
  # file rather than trusting the cgroup, so a session never leaves a daemon
  # behind for the next one to collide with.
  systemd.user.services.calcurse-daemon = {
    Unit = {
      Description = "Calcurse appointment notifications";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      # `calcurse-notify` is resolved from this PATH when the daemon fires,
      # and a daemon started by systemd does not inherit the session's.
      Environment = "PATH=%h/.nix-profile/bin:/run/current-system/sw/bin";
      ExecStart = "${pkgs.calcurse}/bin/calcurse --daemon";
      ExecStop = "${calcurseDaemonStop}/bin/calcurse-daemon-stop";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
