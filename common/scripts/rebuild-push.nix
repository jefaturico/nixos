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
  git_owner_hosts="iapetus odin"

  if [ -z "''${HOSTNAME:-}" ]; then
      printf 'HOSTNAME is not set.\n' >&2
      exit 1
  fi

  if [ ! -x "$sudo" ]; then
      printf 'Expected sudo wrapper at %s.\n' "$sudo" >&2
      exit 1
  fi

  cd "$repo"

  case " $git_owner_hosts " in
    *" $HOSTNAME "*) is_git_owner=1 ;;
    *) is_git_owner=0 ;;
  esac

  if [ "$is_git_owner" -eq 0 ]; then
      "$sudo" ${pkgs.nixos-rebuild}/bin/nixos-rebuild \
          --log-format bar-with-logs \
          --print-build-logs \
          switch \
          --flake "path:$repo#$HOSTNAME"
      exit 0
  fi

  if ! ${pkgs.git}/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      printf 'Expected a valid git repo at %s on Git owner %s.\n' "$repo" "$HOSTNAME" >&2
      exit 1
  fi

  ${pkgs.git}/bin/git add .
  printf 'Staged current repo changes for flake evaluation.\n'

  "$sudo" ${pkgs.nixos-rebuild}/bin/nixos-rebuild \
      --log-format bar-with-logs \
      --print-build-logs \
      switch \
      --flake "$repo/#$HOSTNAME"

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
