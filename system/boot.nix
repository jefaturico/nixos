{ ... }:

# Boot entry policy and console noise.
{
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 5;
    };
    timeout = 0;
    efi.canTouchEfiVariables = true;
  };

  # ly is a console greeter, so it shares a TTY with the kernel and with
  # initrd's progress output. This hardware logs a benign
  # `ucsi_acpi USBC000:00: unknown error 256` at KERN_ERR on every boot, which
  # would otherwise land on top of the greeter. Print only genuinely fatal
  # levels to the console; everything is still recorded in the journal.
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
}
