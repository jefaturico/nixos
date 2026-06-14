# Galileo ↔ Ekman Streaming Setup

This document covers the manual steps after the NixOS configuration is applied:
Tailscale authentication, Sunshine setup on `galileo`, Moonlight setup on `ekman`,
and the basic LAN/remote streaming workflow.

## 1. Apply the NixOS Config

Commit or stage the new files before rebuilding, because flakes only include files
known to Git.

```sh
git add .sops.yaml common/secrets.nix secrets/secrets.yaml STREAMING.md
sudo nixos-rebuild switch --flake .#galileo
sudo nixos-rebuild switch --flake .#ekman
```

Run the host-specific rebuild command on each machine.

After the first rebuild:

- `galileo` should use SDDM and offer/start the `niri` session.
- `galileo` should run the user-level `sunshine.service`.
- `ekman` should have the `moonlight`/`moonlight-qt` launcher available.
- Both hosts should have `tailscaled.service` available.

Useful checks:

```sh
systemctl status display-manager
systemctl status tailscaled
systemctl --user status sunshine
```

The Sunshine unit only exists on `galileo`, and it is a user service. Use
`systemctl --user ...`, not plain `systemctl ...`.

## 2. Tailscale Login

Tailscale is configured without declarative auth keys for now. Authenticate each
host interactively.

On `galileo`:

```sh
sudo tailscale up --hostname=galileo
tailscale status
```

On `ekman`:

```sh
sudo tailscale up --hostname=ekman
tailscale status
```

The `tailscale up` command opens a login URL. Open it in a browser, authenticate,
and approve the machine in your tailnet if prompted.

Recommended Tailscale admin settings:

- Keep MagicDNS enabled so `ekman` can reach `galileo` by name.
- Do not expose Sunshine through router port forwarding.
- Keep both machines in the same tailnet.
- If university/work networks block direct UDP, Tailscale may use DERP relay; this
  works but can add latency.

Connectivity checks from `ekman`:

```sh
tailscale ping galileo
ping galileo
```

If MagicDNS is unavailable, use Galileo’s Tailscale IP from:

```sh
tailscale ip -4 galileo
```

## 3. Sunshine Setup on Galileo

Open Sunshine’s web UI on `galileo`:

```text
https://localhost:47990
```

The browser may warn about a self-signed certificate. That is expected for the
local Sunshine admin UI.

Initial GUI steps:

1. Create the Sunshine admin username/password.
2. Confirm the service is running.
3. Verify the display/session appears under the configured outputs.
4. Leave Sunshine pairing/auth state managed by Sunshine itself.

Useful CLI checks on `galileo`:

```sh
systemctl --user status sunshine
journalctl --user -u sunshine -b --no-pager
```

If capture fails, check Sunshine logs first. The NixOS config enables Sunshine
with `CAP_SYS_ADMIN`, which is required for DRM/KMS capture.

For this setup, Sunshine has been tested with capture mode set to `KMS` in the
Sunshine web UI.

Do not start `sunshine` manually while the user service is running. If a manual
run exits with `Couldn't bind RTSP server to port [48010], Address already in
use`, another Sunshine process is already listening. Check/restart the user
service instead:

```sh
systemctl --user restart sunshine
systemctl --user status sunshine
```

## 4. Moonlight Setup on Ekman

Start Moonlight from the launcher or CLI:

```sh
moonlight
```

LAN pairing:

1. Make sure both machines are on the same LAN.
2. Open Moonlight on `ekman`.
3. Select `galileo` if it appears automatically.
4. If it does not appear, add Galileo manually by LAN IP or hostname.
5. Moonlight shows a PIN.
6. Enter the PIN in Sunshine’s web UI on `galileo`.
7. Start a desktop stream and verify input/audio/video.

Tailscale pairing/connection:

1. Make sure both hosts show as online in `tailscale status`.
2. In Moonlight, add `galileo` manually using MagicDNS name `galileo`, or use
   Galileo’s Tailscale IPv4 address.
3. Pair the same way as LAN pairing.
4. Start with a conservative bitrate, then increase if latency and packet loss
   are acceptable.

Useful Moonlight CLI examples:

```sh
moonlight pair galileo
moonlight stream galileo
```

If MagicDNS does not resolve, replace `galileo` with the Tailscale IPv4 address.

Moonlight input capture:

- Click inside the stream window first; on some Wayland sessions, unfocused
  windows will not forward keyboard/mouse input.
- Use fullscreen or borderless fullscreen for the most reliable keyboard capture.
- On `ekman`, Niri normally keeps `Mod`/Super shortcuts for the local compositor.
  With the Moonlight window focused, press `Mod+Ctrl+Escape` to toggle Niri
  keyboard-shortcut inhibition for that window. After that, Super-based shortcuts
  should be forwarded to `galileo`.
- Press `Ctrl+Alt+Shift+L` to lock/unlock the mouse cursor to the Moonlight
  window.
- Press `Ctrl+Alt+Shift+M` to toggle Moonlight mouse mode.
- If you get stuck with local shortcuts inhibited, press `Mod+Ctrl+Escape` again.
  This binding is deliberately configured with `allow-inhibiting=false`, so it
  remains available as the escape hatch.
- If the stream is visible but no host input works, check Sunshine logs on
  `galileo` for virtual input errors before debugging Moonlight further.

## 5. Remote Streaming Checklist

Before leaving home:

- `galileo` is powered on and not asleep.
- `tailscale status` shows `galileo` online.
- `systemctl --user status sunshine` is healthy on `galileo`.
- Sunshine has already been paired with Moonlight at least once.
- No router port forwarding is required.

From the remote network:

```sh
tailscale status
tailscale ping galileo
moonlight
```

Then connect to `galileo` from Moonlight.

## 6. Secrets and SOPS Maintenance

The vdirsyncer OAuth env file is now stored in encrypted form at:

```text
secrets/secrets.yaml
```

The old plaintext file should not exist:

```text
secrets/vdirsyncer-google-calendar.env
```

To edit encrypted secrets from `galileo`:

```sh
nix shell nixpkgs#sops -c sops secrets/secrets.yaml
```

If `ekman` later needs to decrypt secrets directly, add an `ekman` age recipient
to `.sops.yaml`, rotate/update `secrets/secrets.yaml`, and add the corresponding
key path in `common/secrets.nix`.

## 7. Troubleshooting

Sunshine not reachable:

```sh
systemctl --user status sunshine
journalctl --user -u sunshine -b --no-pager
systemctl --user restart sunshine
```

If `systemctl status sunshine` says the unit does not exist, that is expected:
Sunshine is a user service. Use `systemctl --user status sunshine`.

If `systemctl --user status sunshine` says the unit does not exist after a
successful rebuild, reload user units or log out and back in:

```sh
systemctl --user daemon-reload
systemctl --user start sunshine
```

If a manual `sunshine` run reports input permission warnings, prefer the user
service. The NixOS module sets up the wrapper/permissions expected by Sunshine.

If the stream works but Moonlight cannot control mouse/keyboard, check
`/dev/uinput` permissions on `galileo`:

```sh
ls -l /dev/uinput
id
```

The repo config enables NixOS `hardware.uinput` support and adds `jefaturico` to
the `uinput` group. Group membership is captured at login, so after applying this
change, fully log out and back in or reboot:

```sh
sudo nixos-rebuild switch --flake ~/nixos/#galileo
reboot
```

After logging back in, verify `id` includes `uinput` and `/dev/uinput` is owned
by group `uinput`.

If a manual `sunshine` run reports `Cannot load libcuda.so.1` or VAAPI encode
failures but software encoding works, first test through the user service logs.
Manual runs do not necessarily match the service environment.

If the user service log reports `Cannot load libnvidia-encode.so.1`, rebuild
`galileo` from this repo and restart Sunshine. The config exposes
`/run/opengl-driver/lib` to Sunshine’s user unit so NVENC can find NVIDIA driver
libraries:

```sh
sudo nixos-rebuild switch --flake ~/nixos/#galileo
systemctl --user restart sunshine
journalctl --user -u sunshine -b --no-pager | grep -E 'nvenc|libnvidia-encode|Found H.264 encoder'
```

Warnings about virtual touch screen or pen tablet creation are not blocking for
normal mouse/keyboard streaming. Treat them as actionable only if touch or pen
input is required.

Tailscale not connected:

```sh
systemctl status tailscaled
sudo tailscale up --hostname="$(hostname)"
tailscale status
```

Moonlight cannot find Galileo:

- Try manual add with `galileo`.
- Try manual add with Galileo’s Tailscale IPv4 address.
- Confirm `tailscale ping galileo` works from `ekman`.
- Confirm Sunshine is running on `galileo`.

Bad latency outside home:

- Lower Moonlight bitrate and resolution first.
- Prefer 60 FPS only if latency is stable.
- Check whether Tailscale is using a relay path.

```sh
tailscale ping galileo
```

If it reports DERP/relay, streaming may still work but performance depends on
the external network.
