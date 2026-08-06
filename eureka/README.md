# Eureka

Eureka makes River-managed Wayland windows behave like Emacs buffers. Emacs
owns focus, layout, workspaces and session policy; the native module owns the
Wayland protocol objects and applies the state requested by Emacs.

This directory is self-contained. It can be copied into another repository,
packaged with Nix, built manually, or loaded by an existing Emacs
configuration. Nothing here depends on the personal configuration under
`../dots/emacs`, and the supplied `example.el` deliberately contains no Org,
Org-roam, gptel, finance, feed-reader or NixOS-specific configuration.

Eureka is a fork of [Reka](https://codeberg.org/tazjin/reka). The fork adds a
stable numeric window-ID boundary, coalesced and versioned layout updates,
safer lifecycle handling, output hotplug recovery, and River input-device
configuration from Emacs Lisp.

## Contents

- `src/` — native Rust Emacs module and River event worker.
- `protocol/` — River protocols consumed by the native module.
- `lisp/eureka.el` — the reusable Emacs package. It contains mechanism, not a
  personal desktop policy.
- `example.el` — a complete but small example policy for launching programs,
  arranging and closing views, starting a terminal, controlling hardware keys,
  and ending the session.
- `default.nix` — standalone Nix package for the native module and Lisp package.
- `lisp/eureka-tests.el` and Rust unit tests — lifecycle and model tests.

## Requirements

Eureka requires:

- GNU Emacs with dynamic-module support and a graphical PGTK build;
- the current non-monolithic River compositor and its window-management,
  layer-shell, input-management, libinput and XKB-binding protocols;
- Wayland and `libxkbcommon` development files when building manually;
- Rust and Cargo when building manually.

The example policy additionally uses `gio` for desktop-file launching. `foot`,
`waylock`, `wpctl`, `brightnessctl` and `systemctl` are optional: only their
corresponding commands fail when the executable is absent. A notification
daemon, idle manager, portal implementation and polkit agent remain independent
session components; Eureka does not need to own them.

## Install with Nix

Import the directory with the same Emacs variant that will load the module:

```nix
let
  eureka = pkgs.callPackage ./path/to/eureka {
    emacs = pkgs.emacs-pgtk;
  };

  myEmacs = (pkgs.emacsPackagesFor pkgs.emacs-pgtk).emacsWithPackages
    (epkgs: [
      eureka
      # Existing packages from your own configuration go here.
    ]);
in
myEmacs
```

Using the same Emacs derivation matters because native Emacs modules are loaded
into that process. The Nix expression keeps Rust/protocol changes in the native
build and packages `eureka.el` on the resulting Emacs load path.

To build the package directly in a checkout:

```sh
nix-build eureka/default.nix
```

## Install without Nix

From this directory:

```sh
cargo build --release
install_dir="${XDG_DATA_HOME:-$HOME/.local/share}/emacs/site-lisp/eureka"
mkdir -p "$install_dir"
install -m 755 target/release/libeureka.so "$install_dir/libeureka.so"
install -m 644 lisp/eureka.el "$install_dir/eureka.el"
```

Add that directory to Emacs before requiring Eureka:

```elisp
(add-to-list 'load-path
             (expand-file-name
              "emacs/site-lisp/eureka"
              (or (getenv "XDG_DATA_HOME") "~/.local/share")))
(require 'eureka)
```

The native library must be named `libeureka.so`, because `eureka.el` requires
the feature `libeureka` before defining the Lisp-side integration.

## Plug Eureka into an existing Emacs

The minimal integration is:

```elisp
(require 'eureka)

(setq eureka-intercept-prefixes
      '("s-x" "s-q" "s-SPC" "s-/" "s--"))

;; Set input preferences before enabling Eureka.
(setq eureka-input-repeat-rate 60
      eureka-input-repeat-delay 200
      eureka-touchpad-tap t
      eureka-touchpad-natural-scroll t)

;; Call only inside the River session that Eureka should manage.
(when (getenv "EUREKA_SESSION")
  (eureka-enable))
```

`eureka-enable` installs the necessary window/focus hooks and global advice.
`eureka-disable` removes them and releases River without closing the graphical
clients. An existing Emacs configuration may bind arbitrary commands to the
intercepted keys; Eureka sends those key events to Emacs while ordinary client
input continues directly to the focused Wayland client.

Do not enable Eureka in a general-purpose daemon shared by unrelated graphical
sessions. Start a dedicated Emacs process inside River so its frame geometry,
input interception and lifecycle belong to one compositor session.

## Use the supplied example policy

Place this directory on `load-path`, then load `example.el` and start it:

```elisp
(add-to-list 'load-path "/absolute/path/to/eureka/lisp")
(load "/absolute/path/to/eureka/example.el" nil nil t)

(setq eureka-example-terminal-command '("foot")
      eureka-example-lock-command '("waylock"))

(eureka-example-start)
```

The example uses a global minor-mode keymap rather than overwriting global
bindings individually. All names begin with `eureka-example-`, so copying or
requiring it does not claim the user's personal namespace.

Default example bindings:

| Binding | Action |
| --- | --- |
| `Super-x` | Select an XDG graphical application |
| `Super-Return` | Start the configured terminal |
| `Super-q` | Close the selected client view or ordinary Emacs view |
| `Super-Space` | Select an Emacs/client buffer |
| `Super-o` | Focus the next Emacs window |
| `Super-/` | Split right |
| `Super--` | Split below |
| `Ctrl-Super-f` | Toggle native client fullscreen |
| `Super-Escape` | Lock, suspend, exit, reboot or power off |
| Hardware media keys | Volume, microphone and brightness control |

With a prefix argument, `eureka-example-launch-program` refreshes its cached
desktop-file list. Call `eureka-example-stop` to disable both Eureka and the
example keymap.

The example intentionally omits notification presentation, status bars,
wallpaper, portals, idle locking and a login-manager entry. Those are separate
programs and differ between systems. A session launcher should start them, set
its environment, and finally execute Emacs.

## Start from River

Current River accepts a program as its configuration/WM process. A minimal
launcher looks like:

```sh
#!/bin/sh
set -eu

export EUREKA_SESSION=1
export XDG_CURRENT_DESKTOP=river
export XDG_SESSION_TYPE=wayland

# Optional independent session services:
# mako &
# swayidle ... &
# /path/to/polkit-agent &

exec emacs \
  --init-directory "$HOME/.config/emacs" \
  --load "/absolute/path/to/eureka/example.el" \
  --eval '(eureka-example-start)'
```

Then start River with that executable:

```sh
exec river -c "$HOME/.config/river/eureka-init"
```

Use absolute paths in a display-manager session: its environment and working
directory are often smaller and less predictable than an interactive shell.

## Custom policy

`example.el` is reference code, not a required layer. A mature configuration
will normally define its own global minor mode and lifecycle function. The
important ordering is:

1. Require `eureka`.
2. Set `eureka-intercept-prefixes` and input options.
3. Install any `eureka-enable-hook` integrations.
4. Enable the user's key policy.
5. Call `eureka-enable`.

Commands implemented directly by the native worker must also be registered:

```elisp
(add-hook
 'eureka-enable-hook
 (lambda ()
   (eureka-push-intercept-prefix "C-s-f" 'toggle-fullscreen)))
```

## Development and validation

Run from `eureka/`:

```sh
cargo check
cargo clippy --all-targets -- -D warnings
cargo test
emacs --batch -Q -L lisp \
  -l lisp/eureka-tests.el \
  -f ert-run-tests-batch-and-exit
emacs --batch -Q -L lisp \
  -l example.el \
  --eval '(message "example loaded")'
```

The final command validates Lisp loading but does not call
`eureka-example-start`: native startup requires a live River session and its
protocol globals.

Set `EUREKA_DEBUG=1` before starting the session for verbose native logging.
Because Eureka is the window manager, keep a TTY or a second River WM available
while developing policy code.

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
