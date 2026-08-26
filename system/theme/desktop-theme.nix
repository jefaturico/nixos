{
  writeShellApplication,
  coreutils,
  dconf,
  libnotify,
  mako,
  procps,
}:

# The single place the light/dark decision is made. Everything else either
# reads the portal's appearance setting (GTK, Qt, LibreWolf) or gets nudged
# by this script at runtime (mako), so no application ever needs to be
# restarted and no application is themed by hand.
#
#   desktop-theme            print the current theme
#   desktop-theme dark|light switch to that theme
#   desktop-theme toggle     switch to the other one
#   desktop-theme apply      re-apply the stored theme (session startup)
#   desktop-theme files      only refresh the on-disk fragments, no runtime
#                            calls; used from Home Manager activation, which
#                            runs outside the graphical session
writeShellApplication {
  name = "desktop-theme";
  runtimeInputs = [
    coreutils
    dconf
    libnotify
    mako
    procps
  ];
  text = builtins.readFile ../../scripts/desktop-theme.sh;
}
