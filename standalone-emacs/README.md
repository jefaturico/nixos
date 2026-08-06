# Standalone Emacs configuration

This is a portable copy of the ordinary Emacs configuration from
`../dots/emacs`. It contains editing, completion, Org, Org-roam, feeds,
terminal, finance, programming, NixOS and gptel support. It contains no Eureka
package, River session policy, Eureka key interception, client-buffer lookup,
notification-server integration or Eureka startup instrumentation.

The directory can be copied or cloned directly to `~/.config/emacs`:

```sh
git clone REPOSITORY ~/.config/emacs
emacs --init-directory "$HOME/.config/emacs"
```

When this directory lives inside a larger checkout instead, symlink it:

```sh
ln -s /absolute/path/to/standalone-emacs ~/.config/emacs
```

## Package behavior

`lisp/jf-package-bootstrap.el` follows this order for every required library:

1. Use it when it is already exposed on Emacs's `load-path`. This is how
   Nix-provided Emacs packages are detected.
2. Use an existing package.el installation when present.
3. Only then refresh package metadata and download the missing package.

This avoids duplicating Nix packages in `~/.emacs.d/elpa` while allowing the
same configuration to start under an ordinary distribution-provided Emacs.
GNU ELPA, NonGNU ELPA and MELPA are configured as fallback archives. Package
metadata is refreshed at most once in a startup, and only if something is
missing.

The test is based on `locate-library`, not only `package-installed-p`:
package.el generally cannot see that Nix already placed a library on the load
path.

The first non-Nix startup therefore requires network access and can take a few
minutes, particularly while compiling `vterm`. Subsequent starts use the local
package directory and do not refresh the archives.

## Nix installation

`default.nix` builds an Emacs containing the Lisp dependencies:

```sh
nix-build default.nix
./result/bin/emacs --init-directory "$PWD"
```

Or import it from another expression:

```nix
let
  myEmacs = pkgs.callPackage ./path/to/standalone-emacs {
    emacs = pkgs.emacs-pgtk;
  };
in
myEmacs
```

The expression pins an OAuth-capable gptel revision because the copied
`jf-gptel.el` configuration uses `gptel-openai-oauth`, which is absent from
older nixpkgs versions. Update its revision and fixed-output hash together.

The bootstrap remains enabled in the Nix build. Normally it downloads nothing,
because every required library is already discoverable. If a pinned nixpkgs
package lacks a newly required companion library, only that missing package is
installed through package.el rather than failing the entire configuration.

## External programs

Lisp packages are bootstrapped automatically; system executables are not.
Install the ones corresponding to the features you use:

| Feature | Executables |
| --- | --- |
| Python LSP | `basedpyright-langserver` |
| Nix LSP and formatting | `nil`, `nixfmt` |
| Typst editing/preview | `typst`, `tinymist`, `typstyle` |
| LaTeX fragments in Org | a TeX installation and `dvisvgm` |
| Vterm | a compiler toolchain, CMake and libvterm headers when package.el must build it |
| PDF picker | `fd`, `zathura` |
| Finance | `hledger` |
| Browser integration | `brave` for the configured secondary browser |
| Search | `ripgrep` for Consult grep commands |
| NixOS rebuild UI | `nix`, `nixos-rebuild`, `sudo` |
| AI requests | `curl`; ChatGPT OAuth login is requested when first used |

Missing optional executables do not affect ordinary startup; the associated
interactive command reports what is absent when invoked.

## Personal paths to review

This is a faithful copy, so a few data paths remain personal defaults:

- `~/documents/org/` for Org agenda and capture;
- `~/documents/roam/` and `~/documents/diving/` for Org-roam profiles;
- `~/documents/org/drill/` for flashcards;
- `~/documents/personal/finance/main.journal` for hledger;
- `~/nixos/common/bookmarks.txt` for the plain-text bookmark list;
- `~/nixos/` for the NixOS rebuild command.

They are not accessed merely by loading the configuration, except that
Org-roam creates/opens its configured database when initialized. Change these
variables in the corresponding `lisp/jf-*.el` file or with `setq` after loading
the module.

## Structure

- `early-init.el` — startup performance and frame defaults, with no Eureka
  logging.
- `init.el` — package bootstrap and module loading.
- `lisp/jf-package-bootstrap.el` — Nix-aware package fallback.
- `lisp/jf-core.el` — persistence, editor defaults and unsaved-buffer shutdown
  inhibition.
- `lisp/jf-ui.el`, `jf-modeline.el`, `jf-completion.el` — presentation and
  completion.
- `lisp/jf-programming.el` — Eglot and language modes.
- `lisp/jf-org.el`, `jf-org-roam.el` — tasks, capture, notes and flashcards.
- `lisp/jf-tools.el` — feeds, EWW, vterm, hledger, PDFs and bookmarks.
- `lisp/jf-network.el`, `jf-nixos.el`, `jf-gptel.el` — standalone integrations.

## Validation

Check syntax without loading third-party packages:

```sh
for file in early-init.el init.el lisp/*.el; do
  emacs --batch -Q --eval "(byte-compile-file \"$file\")"
done
```

Test a real startup using packages already supplied by Nix:

```sh
emacs --batch --init-directory "$PWD" \
  --eval '(message "standalone configuration loaded")'
```

Verify the fallback logic without downloading anything:

```sh
emacs --batch -Q \
  -L lisp \
  -l tests/package-bootstrap-tests.el \
  -f ert-run-tests-batch-and-exit
```

The tests stub `package-refresh-contents` and `package-install`. They verify
that libraries on `load-path` are never passed to package installation and
that multiple missing packages refresh archive metadata only once.

## Differences from the live configuration

- All `jf-eureka-*` modules and their tests are absent.
- The Eureka startup-timing environment variables are ignored.
- The UI no longer references `eureka-mode-hook`.
- Bookmark opening no longer searches Eureka client buffers; it simply opens
  the selected URL.
- No OAuth token, cache, database, history or other generated state is copied.
