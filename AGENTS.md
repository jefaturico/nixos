# Repository instructions

These instructions apply to the entire repository. Keep public architecture,
usage, and maintenance explanations in `README.md` files; keep only durable
agent behavior and routing here.

## Start here

- Read `README.md` before changing the system architecture or shared modules.
- For Tethys hardware, power, lid, refresh-rate, VRR, Steam-session, storage,
  resume, or Framework-specific work, also read `hosts/tethys/README.md`.
- For Titan hardware, NVIDIA, storage, display, or desktop-specific work, also
  read `hosts/titan/README.md`.
- For Iapetus server, SSH/Tailscale, Syncthing, storage, thermal, or power work,
  also read `hosts/iapetus/README.md`.
- Inspect `git status --short` before editing. The worktree commonly contains
  user changes; preserve them and never clean, reset, restore, or reformat
  unrelated paths.
- Treat current files on disk as the implementation source of truth. Use the
  nearest README for design context, then verify claims against Nix/C/shell
  source before changing behavior.
- Before proposing or implementing a solution, inspect the relevant host,
  shared modules, hardware constraints, existing packages/services, and
  adjacent code paths. Solutions must be tailored to this repository and the
  affected machine, not copied from generic NixOS advice.

## Design priorities

Optimize decisions for these goals, in order of relevance to the task:

1. Performance and responsiveness.
2. Battery and resource efficiency, especially on Tethys.
3. Simplicity and minimal moving parts.
4. A minimal system, dependency set, service graph, and maintenance burden.

- Prefer a well-maintained Nixpkgs option, upstream feature, community package,
  or community patch that fits the pinned versions over new custom code.
- Reuse does not override suitability: inspect implementation quality,
  dependencies, activity, compatibility, and runtime cost before adopting a
  community solution.
- Write local code only when existing solutions do not fit the actual system or
  when a small, isolated implementation is clearly simpler and more robust.
  Document why it exists and how it is tested or upgraded.
- Avoid speculative abstractions, duplicate state, extra daemons, polling,
  broad frameworks, and dependencies for behavior that can remain declarative
  or use an existing session/service boundary.
- When performance and battery efficiency conflict, prefer an explicit
  host/power-state policy such as Tethys's AC/battery refresh split rather than
  one compromise applied everywhere.
- Do not claim that a change improves performance, latency, memory use, power
  consumption, or battery life without a relevant measurement. When direct
  measurement is impractical, label the benefit as expected and state the
  mechanism and tradeoff instead of presenting it as proven.

## Command execution and user handoff

- Run every safe, relevant, non-interactive command needed to investigate,
  implement, format, and validate the task. Do not tell the user to run a
  command merely to avoid doing the work.
- If an important command fails because of sandbox or network restrictions,
  request the narrowest available tool escalation and retry it yourself.
- Never invoke `sudo`, `su`, `doas`, `nixos-rebuild`, or another privileged
  activation path. Do not request general elevated shell access to work around
  this boundary.
- Stop at unprivileged evaluation and `nix build`. Ask the user to perform a
  command only when it genuinely requires their privilege, authentication,
  secret, physical hardware interaction, GUI judgment, or an irreversible
  choice that is outside the task's authorization.
- When user action remains, first complete every nonprivileged check available,
  then provide only the exact minimal command or manual acceptance step and
  explain why the agent cannot perform it.
- Do not ask the user to copy command output back when the same information can
  be obtained through available read-only inspection.

## Repository ownership

- `flake.nix`: inputs, host outputs, and desktop/server constructors.
- `hosts/<host>/default.nix`: host role and host-only policy.
- `hosts/<host>/hardware.nix`: boot-critical hardware, filesystem, swap, and
  resume facts. Do not regenerate or copy these files between hosts.
- `common/configuration.nix`: shared desktop NixOS policy and imports.
- `common/home.nix`: desktop Home Manager root.
- `common/programs.nix`: programs and imports of `services.nix` and
  `session.nix`.
- `common/services.nix`: Home Manager user services.
- `common/session.nix`: session environment, MIME, GTK/Qt, and desktop
  integration.
- `common/theme.nix` and `common/matugen/`: wallpaper and light/dark theme
  production and propagation.
- `common/niri/`: Tethys's sole compositor session, bindings, desktop helpers,
  portal policy, and graphical-session services.
- `common/scripts.nix` and `common/scripts/`: rebuild, battery, and lid helpers.
- `common/secrets.nix` and `secrets/`: SOPS declarations and encrypted data.
- `common/syncthing.nix`: topology, folders, and ignore patterns.
- `dots/helix/`: active out-of-store editor configuration; edits apply without
  a NixOS rebuild.

## Safety and invariants

- Never print, decrypt into the worktree, or copy into documentation plaintext
  secrets, private keys, filesystem UUIDs, MAC addresses, age recipients,
  public-key bodies, or Syncthing device IDs. Normally there is no reason to
  read `secrets/secrets.yaml`.
- Do not change `system.stateVersion` or `home.stateVersion` during a normal
  channel/package update.
- Iapetus deliberately uses the smaller server constructor and does not inherit
  Home Manager, Flatpak, SOPS integration, or the desktop module stack.
- Tethys must retain disk-backed swap as the hibernation resume device even
  though zram has higher runtime priority.
- `lid-monitor-only` is currently declared without `Install.WantedBy` and is
  not started automatically. Do not silently enable it during unrelated work.
- Tethys's `display-corner-mask` is independent of the selected compositor and
  must remain enabled for graphical sessions unless explicitly requested.
- Niri owns Tethys's `graphical-session.target`; do not add a redundant
  compositor-specific graphical-session target.
- Do not add dependencies, restructure module ownership, or broaden a change to
  “clean up” nearby code unless the task requires it.

## Editing conventions

- Keep host-specific values in the host module and shared behavior in the
  narrowest appropriate `common/` module.
- Prefer Nix module options over hostname checks when behavior is genuinely
  reusable. Existing hostname checks may remain when the behavior is strictly
  machine-specific.
- Use `lib.mkIf`/`lib.optionals` for conditional configuration and
  `pkgs.writeShellApplication` for nontrivial packaged shell helpers with
  explicit runtime dependencies.
- Shell embedded in Nix must use `set -euo pipefail` when appropriate and
  escape shell interpolation as `''${...}`.
- Format only changed Nix files with `nixfmt`; do not run repository-wide
  formatters.
- Keep hardware comments that explain non-obvious boot, driver, swap, resume,
  or device workarounds.
- When behavior, bindings, module interfaces, host specifications, or operating
  procedures change, update the nearest public README in the same change.
- Review documentation on every change. Update the nearest README whenever its
  facts, commands, architecture, behavior, or rationale would otherwise drift;
  update this file whenever durable agent routing, constraints, or validation
  expectations change.
- Do not put agent-only process rules into public READMEs or duplicate full
  public architecture here.

## Validation

Use `path:.` when untracked files must participate in flake evaluation.

For documentation-only changes, verify paths, anchors, commands, and claims
against source. For Nix changes, begin with:

```sh
nix flake check path:. --no-build
```

Then build the affected closure:

```sh
nix build path:.#nixosConfigurations.<host>.config.system.build.toplevel --no-link
```

Minimum build coverage:

- One host module: that host.
- Shared desktop NixOS or Home Manager module: Titan and Tethys.
- Flake inputs, constructors, or cross-host shared logic: all three hosts.
- Theme/session coupling: Titan and Tethys. State the remaining logout/login
  runtime acceptance checks in the handoff.
- Boot, storage, resume, GPU, or display policy: build the host closure and
  state the exact privileged activation and physical acceptance checks that
  remain for the user. Never perform the activation yourself.

Do not run privileged activation, commit, push, update inputs, or edit encrypted
secrets unless the action is both explicitly requested and possible without
violating the no-privilege rule. Report pre-existing failures separately from
failures introduced by the current work.

## Review expectations

- Check that every host-specific option is valid for the host constructor that
  evaluates it.
- Check service lifecycle, not just declaration: `WantedBy`, `PartOf`, ordering,
  restart policy, and the target that actually starts the unit.
- For shell helpers, review quoting, atomic state updates, permissions, missing
  devices/files, cancellation, and stale PID/process validation.
- For Tethys, check AC/battery transitions, VRR/mode strings, scale, external
  output hotplug, suspend/resume/hibernate, and wallpaper redraw coupling.
