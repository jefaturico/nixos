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
- For Iapetus server, SSH/Tailscale, storage, thermal, or power work, also read
  `hosts/iapetus/README.md`.
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
  host-level policy — Tethys's full-RAM zram against Iapetus's halved zram and
  TLP boost clamp — rather than one compromise applied everywhere.
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

Configuration is organized by feature, not by layer. Each directory under
`features/` is one thing a machine does and owns *everything* that thing needs:
NixOS configuration, Home Manager configuration, helper scripts, patches, and
dotfiles. Do not create a shared `scripts/`, `patches/`, or `dots/` directory
again — a helper belongs beside the feature that installs it.

Every feature exposes the same interface:

- `default.nix` is always a NixOS module and is what hosts import.
- `system.nix` holds the NixOS half when a feature has both halves.
- `home.nix` holds the Home Manager half. `default.nix` wires it with
  `home-manager.users.jefaturico.imports = [ ./home.nix ];`.
- Data files that are not modules (`config.kdl`, `librewolf-chrome.nix`,
  `battery-check.nix`, `patches/`) sit in the same directory.

Importing a feature is what enables it. There are no `enable` options to
maintain, and a feature a host does not import costs that host nothing. When
behaviour should be conditional, change the host's import list rather than
adding a hostname test inside the feature.

- `flake.nix`: inputs, host outputs, and desktop/server constructors. It sets
  up Home Manager but declares no user modules; features attach their own.
- `hosts/<host>/default.nix`: the feature list plus host-only hardware policy.
- `hosts/<host>/hardware.nix`: boot-critical hardware, filesystem, swap, and
  resume facts. Do not regenerate or copy these files between hosts.

`README.md` carries the table of what each feature covers. Read it before
deciding where a change belongs; if a change does not fit an existing feature,
adding a new directory is usually right.

Two features need care:

- `base`, `users`, and `network` are also imported by the headless host.
  Iapetus has no Home Manager, so it imports `features/network/system.nix`
  directly rather than the directory. Anything added to `features/network/
  home.nix` therefore never reaches Iapetus.
- Fnott spans two features on purpose. `compositor` owns its systemd user
  service, because that is a graphical-session concern alongside the idle,
  polkit, and media-inhibit units. `theme` owns the package override, the
  three patches, the themed wrapper, and the generated config, because all of
  those are palette-driven. Do not consolidate them.
- `features/theme/librewolf-chrome.nix` is not a module. It is the literal
  body of a shell heredoc written by `apply-desktop-theme`, so its `${...}`
  references are expanded by shell at apply time and it must stay at column
  zero.

## Safety and invariants

- Never print, decrypt into the worktree, or copy into documentation plaintext
  secrets, private keys, filesystem UUIDs, MAC addresses, age recipients, or
  public-key bodies. Normally there is no reason to
  read `secrets/secrets.yaml`.
- Do not change `system.stateVersion` or `home.stateVersion` during a normal
  channel/package update.
- Iapetus deliberately uses the smaller server constructor and does not inherit
  Home Manager, SOPS integration, or the desktop module stack.
- Tethys must retain disk-backed swap as the hibernation resume device even
  though zram has higher runtime priority.
- `lid-monitor-only` is deliberately declared without `Install.WantedBy`:
  logind owns the lid action and this unit is the manually started
  alternative. Do not add an `Install` section during unrelated work.
- Tethys's `display-corner-mask` is independent of the selected compositor and
  must remain enabled for graphical sessions unless explicitly requested.
- Niri owns Tethys's `graphical-session.target`; do not add a redundant
  compositor-specific graphical-session target.
- `features/compositor/config.kdl` is an active out-of-store link; edits apply
  through niri's live reload without a rebuild. It carries only declared
  settings — upstream reference comments were removed deliberately, so consult
  the niri wiki rather than reintroducing them.
- Titan and Tethys must stay identical above the hardware line. Anything that
  changes the session, applications, keybindings, or theme belongs in a shared
  module, not in a host module. Host modules hold GPU, firmware, power, and
  chassis facts only.
- Iapetus currently has no service role. Do not infer one from its hardware.
- Do not add dependencies, restructure module ownership, or broaden a change to
  “clean up” nearby code unless the task requires it.

## Editing conventions

- Keep host-specific values in the host module and shared behavior in the
  narrowest appropriate feature.
- Place a change by objective, not by layer. A new configured application gets
  its own feature directory and one import line per host; an application with
  nothing to configure gets one line in `features/packages/home.nix`.
- Prefer appending to a shared list (`extraGroups`, `home.packages`,
  `xdg.mimeApps.defaultApplications`) from the owning module over centralizing
  it, so removing a module removes everything it brought.
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
- A refactor is only finished when the derivation closures before and after it
  differ by exactly the intended amount. Compare with
  `nix-store -q --requisites <drv> | grep '\.drv$'` on both revisions.
