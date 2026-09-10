#!/usr/bin/env bash
# Create a git worktree for one or more repos on a shared branch name.
#
#   create-worktree.sh <branch> <repo> [repo...] [--base <base>]
#
#   branch   <type>/<short-kebab-slug>, e.g. fix/social-insurance-circuit-breaker
#   repo     directory name under $BARAKA_SERVICES_ROOT
#   --base   base branch, default: production (fetched from origin); when a repo
#            has no such branch its remote default branch is used instead
#
# Repos live in $BARAKA_SERVICES_ROOT, detected from the working directory when
# unset (default ~/Development/baraka-services). Worktrees land in
# $BARAKA_SERVICES_ROOT/worktrees/<repo>-<type>-<slug> and start with NO
# upstream, so git status/pull/push never point at the base.

set -euo pipefail

SELF=${BASH_SOURCE[0]}
BASE=production
BASE_EXPLICIT=no
BRANCH=
REPOS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      [[ $# -ge 2 ]] || { echo "--base needs a value" >&2; exit 2; }
      BASE=${2#origin/}
      BASE_EXPLICIT=yes
      shift 2
      ;;
    -h|--help)
      awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$SELF"
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

usage() {
  echo "usage: $(basename "$SELF") <branch> <repo> [repo...] [--base <base>]" >&2
}

branch_shape_hint() {
  echo "branch must be <type>/<short-kebab-slug>, e.g. fix/CB-2201-otp-resend-500: $BRANCH" >&2
  echo "types: feature fix refactor chore docs test" >&2
}

is_repos_root() {
  local dir=$1 child repos=0
  for child in "$dir"/*/; do
    [[ -d "${child}.git" || -f "${child}.git" ]] && repos=$((repos + 1))
  done
  [[ $repos -ge 2 || ( $repos -ge 1 && -d $dir/worktrees ) ]]
}

detect_root() {
  local dir candidate
  dir=$PWD
  while :; do
    candidate=$dir
    if is_repos_root "$candidate"; then
      (cd "$candidate" && pwd)
      return 0
    fi
    [[ $dir == / ]] && break
    dir=$(dirname "$dir")
  done
  for candidate in "$HOME/workspace" "$HOME/Development/baraka-services"; do
    if is_repos_root "$candidate"; then
      (cd "$candidate" && pwd)
      return 0
    fi
  done
  return 1
}

if [[ -z $BRANCH || ${#REPOS[@]} -eq 0 ]]; then
  usage
  exit 2
fi

if [[ $BRANCH =~ ^([A-Za-z]+)/([A-Za-z0-9]+(-[A-Za-z0-9]+)*)$ ]]; then
  TYPE=$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')
else
  branch_shape_hint
  exit 2
fi

case "$TYPE" in
  feature | fix | refactor | chore | docs | test) ;;
  *)
    branch_shape_hint
    exit 2
    ;;
esac

DIR_SUFFIX=${BRANCH//\//-}

if [[ -n ${BARAKA_SERVICES_ROOT:-} ]]; then
  ROOT=$BARAKA_SERVICES_ROOT
  if [[ ! -d $ROOT ]]; then
    echo "repos root does not exist: $ROOT" >&2
    if DETECTED=$(detect_root 2>/dev/null); then
      echo "the checkouts are in $DETECTED — run again with BARAKA_SERVICES_ROOT=$DETECTED" >&2
    fi
    exit 1
  fi
  ROOT=$(cd "$ROOT" && pwd)
elif DETECTED=$(detect_root 2>/dev/null); then
  ROOT=$DETECTED
  echo "BARAKA_SERVICES_ROOT is not set — using the repos root $ROOT" >&2
else
  echo "no repos root found: set BARAKA_SERVICES_ROOT to the directory holding the repo checkouts" >&2
  echo "run again with BARAKA_SERVICES_ROOT=/path/to/checkouts" >&2
  exit 1
fi

for repo in "${REPOS[@]}"; do
  repo_path="$ROOT/$repo"
  [[ -d "$repo_path/.git" || -f "$repo_path/.git" ]] || {
    echo "not a git repo: $repo_path" >&2
    exit 1
  }
done

report() {
  printf '%s\n  path     %s\n  branch   %s\n  base     origin/%s\n  commit   %s\n  upstream %s\n  %s\n' \
    "$1" "$2" "$BRANCH" "$3" "$4" "$5" "$6"
}

worktree_holding() {
  git -C "$1" worktree list --porcelain |
    awk -v b="refs/heads/$BRANCH" '/^worktree /{p=$2} $0=="branch "b{print p; exit}'
}

remote_default_branch() {
  local repo_path=$1 ref
  ref=$(git -C "$repo_path" ls-remote --symref origin HEAD 2>/dev/null |
    awk '/^ref:/{print $2; exit}') || true
  [[ -n $ref ]] && printf '%s' "${ref#refs/heads/}"
}

worktree_upstream() {
  git -C "$1" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null ||
    printf 'none\n'
}

mkdir -p "$ROOT/worktrees"

for repo in "${REPOS[@]}"; do
  repo_path="$ROOT/$repo"
  wt_path="$ROOT/worktrees/$repo-$DIR_SUFFIX"
  base=$BASE
  note=created

  if [[ -e "$wt_path" ]]; then
    if [[ $(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null) == "$BRANCH" ]]; then
      base=$(git -C "$repo_path" config "branch.$BRANCH.base" 2>/dev/null || true)
      [[ -n $base ]] || base=$BASE
      report "$repo" "$wt_path" "$base" \
        "$(git -C "$wt_path" rev-parse --short HEAD)" "$(worktree_upstream "$wt_path")" reused
      continue
    fi
    echo "$repo: $wt_path exists but is on branch $(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null) — skipping" >&2
    continue
  fi

  if holder=$(worktree_holding "$repo_path") && [[ -n $holder ]]; then
    report "$repo" "$holder" "$base" \
      "$(git -C "$holder" rev-parse --short HEAD)" "$(worktree_upstream "$holder")" \
      "skipped — branch already checked out here"
    continue
  fi

  git -C "$repo_path" fetch --quiet origin \
    "+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH" 2>/dev/null || true

  if git -C "$repo_path" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git -C "$repo_path" worktree add "$wt_path" "$BRANCH" --quiet
  elif git -C "$repo_path" show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
    git -C "$repo_path" worktree add --no-track -b "$BRANCH" "$wt_path" "origin/$BRANCH" --quiet
  else
    if ! git -C "$repo_path" fetch --quiet origin "$base"; then
      if git -C "$repo_path" show-ref --verify --quiet "refs/remotes/origin/$base"; then
        echo "$repo: origin is unreachable — using the last fetched origin/$base" >&2
      else
        if [[ $BASE_EXPLICIT == yes ]]; then
          echo "$repo: cannot fetch origin/$base" >&2
          exit 1
        fi
        if ! base=$(remote_default_branch "$repo_path") || [[ -z $base ]]; then
          echo "$repo: cannot reach origin to fetch a base branch" >&2
          exit 1
        fi
        echo "$repo: origin/$BASE does not exist — using the remote default branch origin/$base" >&2
        git -C "$repo_path" fetch --quiet origin "+refs/heads/$base:refs/remotes/origin/$base" || {
          echo "$repo: cannot fetch origin/$base" >&2
          exit 1
        }
        note="created — base origin/$base is the remote default, not origin/$BASE"
      fi
    fi
    git -C "$repo_path" worktree add --no-track -b "$BRANCH" "$wt_path" "origin/$base" --quiet
    git -C "$repo_path" config "branch.$BRANCH.base" "$base"
  fi

  report "$repo" "$wt_path" "$base" \
    "$(git -C "$wt_path" rev-parse --short HEAD)" "$(worktree_upstream "$wt_path")" "$note"
done
