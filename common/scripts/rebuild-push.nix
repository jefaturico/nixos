{ pkgs }:
''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail

  if [ "$(${pkgs.coreutils}/bin/id -u)" -eq 0 ]; then
      printf 'Run rebuild-push as your normal user; it will call sudo only for nixos-rebuild.\n' >&2
      exit 1
  fi

  repo="''${HOME}/nixos"
  sudo="/run/wrappers/bin/sudo"

  if [ -z "''${HOSTNAME:-}" ]; then
      printf 'HOSTNAME is not set.\n' >&2
      exit 1
  fi

  if [ ! -x "$sudo" ]; then
      printf 'Expected sudo wrapper at %s.\n' "$sudo" >&2
      exit 1
  fi

  if [ ! -d "$repo/.git" ]; then
      printf 'Expected a git repo at %s.\n' "$repo" >&2
      exit 1
  fi

  cd "$repo"

  "$sudo" ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake "$repo/#$HOSTNAME"

  printf 'Commit and push changes? [y/N] '
  IFS= read -r publish

  case "$publish" in
      y|Y|yes|YES)
          ;;
      *)
          printf 'Rebuild complete. Skipping commit and push.\n'
          exit 0
          ;;
  esac

  ${pkgs.git}/bin/git add .

  if ${pkgs.git}/bin/git diff --cached --quiet; then
      printf 'No changes to commit.\n'
      exit 0
  fi

  ${pkgs.git}/bin/git status --short

  printf 'Commit message: '
  IFS= read -r commit_message

  if [ -z "$commit_message" ]; then
      printf 'Commit message cannot be empty.\n' >&2
      exit 1
  fi

  ${pkgs.git}/bin/git commit -m "$commit_message"

  branch="$(${pkgs.git}/bin/git symbolic-ref --quiet --short HEAD)"
  remote="$(${pkgs.git}/bin/git config "branch.$branch.remote" || printf '%s\n' origin)"

  ${pkgs.git}/bin/git push "$remote" "HEAD:$branch"
''
