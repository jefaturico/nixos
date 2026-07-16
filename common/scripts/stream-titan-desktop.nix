{ pkgs }:
''
  #!${pkgs.dash}/bin/dash

  exec ${pkgs.moonlight-qt}/bin/moonlight stream titan Desktop
''
