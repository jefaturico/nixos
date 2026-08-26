{ ... }:

# PipeWire, with the PulseAudio shim applications expect.
{
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # nixpkgs' graphical-desktop module enables speech-dispatcher by default,
  # which drags in espeak-ng and ~650 MB of mbrola voice data. No screen
  # reader or text-to-speech is used on this machine.
  services.speechd.enable = false;
}
