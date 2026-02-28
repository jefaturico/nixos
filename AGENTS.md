# NixOS Configuration Rules

## Core Principles
- Keep configurations minimal. Avoid "bloat" packages or unnecessary services.
- Optimize for resource efficiency, especially on Ekman (8GB RAM).
- No comments in configuration files.
- Blunt, direct communication. No conversational filler.

## Hardware Profiles
- **Galileo (Desk PC):** - Components: NVIDIA GTX 1080 Ti, Intel i7, 32GB RAM.
  - Focus: Performance and proprietary driver stability.
- **Ekman (Huawei MateBook):** - Components: Intel i5, 8GB RAM.
  - Focus: Extreme resource efficiency and power management.

## Project Structure & Scope
- `flake.nix`: Main entry point for both hosts.
- `common/configuration.nix`: Shared system-level settings for both machines.
- `home.nix`: Shared Home Manager configuration.
- `hosts/<hostname>/hardware.nix`: Specific hardware-scan results and bus IDs.
- `hosts/<hostname>/default.nix`: Host-specific overrides and unique service enables.

## Workflow Instructions
1. Check `common/` before adding to `hosts/` to avoid duplication.
2. Ensure `river` (Wayland) configurations are lean.
3. Validate changes with `sudo nixos-rebuild dry-activate --flake .#<hostname>` before full switching.