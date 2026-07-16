# Eureka

Eureka makes River-managed Wayland windows behave like Emacs buffers. Emacs
owns focus, layout, workspaces, and session policy; the native module owns
Wayland protocol objects and applies Emacs's requested state.

Eureka is a fork of [Reka](https://codeberg.org/tazjin/reka). The fork adds a
stable numeric window-ID boundary, coalesced and versioned layout updates,
safer lifecycle handling, output hotplug recovery, and River input-device
configuration from Emacs Lisp.

## Architecture

- Rust connects to River and owns all Wayland proxies.
- Each client receives a stable integer ID exposed to Emacs.
- Each client is represented by an `eureka-mode` buffer.
- Emacs sends the final pixel geometry for visible client buffers.
- Layout and focus are published as one versioned state update; unchanged
  geometry is omitted from focus-only updates.
- Protocol-independent lifecycle and generation rules live in `src/model.rs`
  and are covered by unit tests.
- Input policy is configured in Lisp and applied by Rust to current and
  hot-plugged devices.

## Building

The NixOS configuration packages and launches Eureka through
`common/eureka.nix`. To check the native module directly:

```sh
cargo check
cargo clippy --all-targets -- -D warnings
cargo test
emacs --batch -Q -L lisp -l lisp/eureka-tests.el -f ert-run-tests-batch-and-exit
```

The Lisp entry point is:

```elisp
(require 'eureka)
(eureka-enable)
```

The local graphical-session policy is in `dots/emacs/lisp/jf-eureka.el`.

## Status

Eureka is a work in progress and is tailored to this configuration. The
upstream source and pre-rename fork are preserved under `references/`.
