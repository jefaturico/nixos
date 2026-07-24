{
  pkgs,
  codec ? null,
  qtPlatform ? null,
  resolution ? null,
}:
''
  #!${pkgs.dash}/bin/dash

  ${if qtPlatform == null then "" else "export QT_QPA_PLATFORM=${qtPlatform}"}
  exec ${pkgs.moonlight-qt}/bin/moonlight${if codec == null then "" else " --codec ${codec}"}${
    if resolution == null then "" else " --resolution ${resolution}"
  } stream titan Desktop
''
