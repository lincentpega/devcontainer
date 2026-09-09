#!/usr/bin/env bash
# Create a git worktree for one or more repos on a shared branch name.
#
#   create-worktree.sh <branch> <repo> [repo...] [--base <base>]
#
#   branch   <type>/<slug>, e.g. fix/social-insurance-circuit-breaker
#   repo     directory name under ~/Development/baraka-services
#   --base   base branch, default: production (fetched from origin)
#
# Worktrees land in ~/Development/baraka-services/worktrees/<repo>-<type>-<slug>
# and start with NO upstream, so git status/pull/push never point at the base.

set -euo pipefail

ROOT="$HOME/Development/baraka-services"
BASE=production
BRANCH=
REPOS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      [[ $# -ge 2 ]] || { echo "--base needs a value" >&2; exit 2; }
      BASE=$2
      shift 2
      ;;
    -h|--help)
      sed -n '2,13p' "$0" | cut -c3-
      exit 0
      ;;
    -*)
      echo "unknown option: $1" >&2
      exit 2
      ;;
    *)
      if [[ -z $BRANCH ]]; then BRANCH=$1; else REPOS+=("$1"); fi
      shift
      ;;
  esac
done

if [[ -z $BRANCH || ${#REPOS[@]} -eq 0 ]]; then
  echo "usage: $(basename "$0") <branch> <repo> [repo...] [--base <base>]" >&2
  exit 2
fi

if [[ ! $BRANCH =~ ^[a-z]+/[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "branch must look like <type>/<short-kebab-slug>: $BRANCH" >&2
  exit 2
fi

DIR_SUFFIX=${BRANCH//\//-}

for repo in "${REPOS[@]}"; do
  repo_path="$ROOT/$repo"
  [[ -d "$repo_path/.git" || -f "$repo_path/.git" ]] || {
    echo "not a git repo: $repo_path" >&2
    exit 1
  }
done

for repo in "${REPOS[@]}"; do
  repo_path="$ROOT/$repo"
  wt_path="$ROOT/worktrees/$repo-$DIR_SUFFIX"

  if [[ -e "$wt_path" ]]; then
    echo "$repo: worktree already exists at $wt_path — reusing" >&2
    continue
  fi

  if git -C "$repo_path" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    existing=$(git -C "$repo_path" worktree list --porcelain |
      awk -v b="refs/heads/$BRANCH" '/^worktree /{p=$2} $0=="branch "b{print p}')
    echo "$repo: branch $BRANCH already checked out at ${existing:-unknown} — skipping" >&2
    continue
  fi

  git -C "$repo_path" fetch origin "$BASE" -q
  git -C "$repo_path" worktree add --no-track -b "$BRANCH" "$wt_path" "origin/$BASE" -q

  commit=$(git -C "$wt_path" rev-parse --short HEAD)
  upstream=$(git -C "$wt_path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo none)
  printf '%s\n  path     %s\n  branch   %s\n  base     origin/%s\n  commit   %s\n  upstream %s\n' \
    "$repo" "$wt_path" "$BRANCH" "$BASE" "$commit" "$upstream"
done
