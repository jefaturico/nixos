{ ... }:
{
  # Flatpaks, declared. Add an app ID to `packages` and rebuild, it gets
  # installed from flathub. IDs are the last part of the app's flathub URL.
  services.flatpak = {
    enable = true;

    packages = [
      # "com.stremio.Stremio"
    ];

    # Removing a line from the list above uninstalls the app.
    uninstallUnmanaged = true;

    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };
}
