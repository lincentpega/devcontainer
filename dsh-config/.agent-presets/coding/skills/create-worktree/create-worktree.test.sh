#!/usr/bin/env bash
# Behaviour tests for create-worktree.sh.
#
#   bash create-worktree.test.sh
#
# Each test builds a throwaway repos root (scratch repo + bare origin) under
# $TMPDIR and drives the real script against it. No network, no real checkouts.

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/create-worktree.sh"
SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/create-worktree-test.XXXXXX")
trap 'rm -rf "$SANDBOX"' EXIT

PASS=0
FAIL=0
CURRENT=

# --- harness ---------------------------------------------------------------

test() {
  CURRENT=$1
  WORK=$SANDBOX/$(printf '%s' "$1" | tr -c 'a-zA-Z0-9' '-')
  rm -rf "$WORK"
  mkdir -p "$WORK/workspace/worktrees" "$WORK/home"
  cd "$WORK/workspace" || exit 1
}

ok() {
  PASS=$((PASS + 1))
  printf 'ok   %s: %s\n' "$CURRENT" "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf 'FAIL %s: %s\n' "$CURRENT" "$1"
}

assert_eq() {
  if [[ -z $2 && -n $1 ]]; then
    fail "$3 — expected [$2], got [$1] (cwd $PWD)"
  elif [[ $1 == "$2" ]]; then
    ok "$3"
  else
    fail "$3 — expected [$2], got [$1] (cwd $PWD)"
  fi
}

assert_match() {
  if [[ $1 == *"$2"* ]]; then ok "$3"; else fail "$3 — [$2] not found in output: $1"; fi
}

assert_no_match() {
  if [[ $1 == *"$2"* ]]; then fail "$3 — unexpected [$2] in output: $1"; else ok "$3"; fi
}

make_repo() {
  local name=$1 branch=${2:-main}
  git init -q --bare "$WORK/remote-$name.git"
  git -C "$WORK/remote-$name.git" symbolic-ref HEAD "refs/heads/$branch"
  git init -q "$WORK/workspace/$name"
  git -C "$WORK/workspace/$name" config user.email t@example.com
  git -C "$WORK/workspace/$name" config user.name t
  echo "$name" >"$WORK/workspace/$name/file.txt"
  git -C "$WORK/workspace/$name" add file.txt
  git -C "$WORK/workspace/$name" commit -qm "$name on $branch"
  git -C "$WORK/workspace/$name" branch -M "$branch"
  git -C "$WORK/workspace/$name" remote add origin "$WORK/remote-$name.git"
  git -C "$WORK/workspace/$name" push -q origin "$branch"
}

run_script() {
  OUT=$(PATH="$PATH" HOME="$WORK/home" bash "$SCRIPT" "$@" 2>&1)
  STATUS=$?
}

run_script_unset_root() {
  OUT=$(HOME="$WORK/home" env -u BARAKA_SERVICES_ROOT bash "$SCRIPT" "$@" 2>&1)
  STATUS=$?
}

# --- tests -----------------------------------------------------------------

test "root auto-detected from cwd when BARAKA_SERVICES_ROOT is unset"
make_repo corebanking-java production
run_script_unset_root feature/auto-detect-root corebanking-java
assert_eq "$STATUS" 0 "exits 0"
assert_eq "$(git -C "$WORK/workspace/worktrees/corebanking-java-feature-auto-detect-root" rev-parse --abbrev-ref HEAD 2>/dev/null)" \
  "feature/auto-detect-root" "worktree created under the detected root"

test "unresolvable root says how to point the script at the checkouts"
mkdir -p "$WORK/workspace/loose-dir"
run_script_unset_root feature/no-root loose-dir
assert_eq "$STATUS" 1 "exits 1"
assert_match "$OUT" "BARAKA_SERVICES_ROOT=" "shows the override to use"

test "a root under \$HOME/workspace is found when the cwd has no repos"
mkdir -p "$WORK/home/workspace/worktrees"
git init -q --bare "$WORK/home-remote.git"
git -C "$WORK/home-remote.git" symbolic-ref HEAD refs/heads/production
git init -q "$WORK/home/workspace/card-service"
git -C "$WORK/home/workspace/card-service" config user.email t@example.com
git -C "$WORK/home/workspace/card-service" config user.name t
echo hi >"$WORK/home/workspace/card-service/f.txt"
git -C "$WORK/home/workspace/card-service" add f.txt
git -C "$WORK/home/workspace/card-service" commit -qm init
git -C "$WORK/home/workspace/card-service" branch -M production
git -C "$WORK/home/workspace/card-service" remote add origin "$WORK/home-remote.git"
git -C "$WORK/home/workspace/card-service" push -q origin production
run_script_unset_root fix/home-root-fallback card-service
assert_eq "$STATUS" 0 "exits 0"
assert_match "$OUT" "using the repos root $WORK/home/workspace" "names the detected root"
assert_eq "$(git -C "$WORK/home/workspace/worktrees/card-service-fix-home-root-fallback" rev-parse --abbrev-ref HEAD 2>/dev/null)" \
  "fix/home-root-fallback" "worktree created under the home root"

test "explicit BARAKA_SERVICES_ROOT pointing nowhere reports the detected root"
make_repo baraka-api production
OUT=$(HOME="$WORK/home" BARAKA_SERVICES_ROOT="$WORK/typo-root" bash "$SCRIPT" feature/pointless-root baraka-api 2>&1)
STATUS=$?
assert_eq "$STATUS" 1 "exits 1"
assert_match "$OUT" "repos root does not exist" "reports the bad root"
assert_match "$OUT" "BARAKA_SERVICES_ROOT=$WORK/workspace" "suggests the detected root"

test "issue-key slug from the naming rules is accepted"
make_repo card-service production
run_script fix/CB-2201-otp-resend-500 card-service
assert_eq "$STATUS" 0 "exits 0"
assert_match "$OUT" "fix/CB-2201-otp-resend-500" "branch created"
assert_eq "$(git -C "$WORK/workspace/worktrees/card-service-fix-CB-2201-otp-resend-500" rev-parse --abbrev-ref HEAD 2>/dev/null)" \
  "fix/CB-2201-otp-resend-500" "worktree on the issue-key branch"

test "malformed branch names are rejected with the shape hint"
make_repo card-service production
run_script "Fix/Foo Bar" card-service
assert_eq "$STATUS" 2 "exits 2"
assert_match "$OUT" "<type>/<short-kebab-slug>" "prints the expected shape"
assert_match "$OUT" "fix/CB-2201-otp-resend-500" "shows a valid example"

test "production base is used when the repo has it"
make_repo paynet-backend production
run_script chore/bump-deps paynet-backend
assert_eq "$STATUS" 0 "exits 0"
assert_match "$OUT" "base     origin/production" "based on origin/production"
assert_eq "$(git -C "$WORK/workspace/worktrees/paynet-backend-chore-bump-deps" rev-parse HEAD 2>/dev/null)" \
  "$(git -C "$WORK/remote-paynet-backend.git" rev-parse production)" "at the production commit"

test "repos without production fall back to the remote default branch"
make_repo social-wallet-flutter main
run_script feature/wallet-parity social-wallet-flutter
assert_eq "$STATUS" 0 "exits 0"
assert_match "$OUT" "origin/main" "reports the base actually used"
assert_eq "$(git -C "$WORK/workspace/worktrees/social-wallet-flutter-feature-wallet-parity" rev-parse HEAD 2>/dev/null)" \
  "$(git -C "$WORK/remote-social-wallet-flutter.git" rev-parse main)" "at the default-branch commit"

test "explicit --base overrides the fallback"
make_repo devcontainer production
git -C "$WORK/workspace/devcontainer" branch main origin/production
git -C "$WORK/workspace/devcontainer" push -q origin main
run_script chore/new-skill devcontainer --base main
assert_eq "$STATUS" 0 "exits 0"
assert_match "$OUT" "base     origin/main" "honours the named base"

test "an explicit --base missing from the remote fails loudly"
make_repo devcontainer main
run_script chore/new-skill devcontainer --base release-9
assert_eq "$STATUS" 1 "exits 1"
assert_match "$OUT" "release-9" "names the missing base"

test "one task spans several repos on the same branch"
make_repo card-service production
make_repo card-issue-service production
run_script fix/shared-ledger-bug card-service card-issue-service
assert_eq "$STATUS" 0 "exits 0"
assert_eq "$(git -C "$WORK/workspace/worktrees/card-service-fix-shared-ledger-bug" rev-parse --abbrev-ref HEAD)" \
  "fix/shared-ledger-bug" "first repo on the branch"
assert_eq "$(git -C "$WORK/workspace/worktrees/card-issue-service-fix-shared-ledger-bug" rev-parse --abbrev-ref HEAD)" \
  "fix/shared-ledger-bug" "second repo on the same branch"

test "created branches carry no upstream"
make_repo corebanking-java production
run_script feature/no-upstream corebanking-java
assert_eq "$STATUS" 0 "exits 0"
upstream_status=0
git -C "$WORK/workspace/worktrees/corebanking-java-feature-no-upstream" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1 ||
  upstream_status=$?
[[ $upstream_status -ne 0 ]] &&
  ok "no upstream is configured" || fail "expected no upstream, git resolved one"
assert_match "$OUT" "upstream none" "reports upstream none"

test "an existing worktree is reused and reported, not recreated"
make_repo corebanking-java production
run_script feature/reuse-me corebanking-java
run_script feature/reuse-me corebanking-java
assert_eq "$STATUS" 0 "exits 0"
assert_match "$OUT" "corebanking-java-feature-reuse-me" "names the reused path"
assert_match "$OUT" "branch   feature/reuse-me" "names the branch it holds"
assert_no_match "$OUT" "fatal" "no git error leaked"
assert_eq "$(git -C "$WORK/workspace/worktrees/corebanking-java-feature-reuse-me" rev-parse --abbrev-ref HEAD)" \
  "feature/reuse-me" "still on the expected branch"

test "a branch already checked out elsewhere is reported and skipped"
make_repo corebanking-java production
git -C "$WORK/workspace/corebanking-java" worktree add -q --no-track -b feature/in-flight "$WORK/other-place" origin/production
run_script feature/in-flight corebanking-java
assert_eq "$STATUS" 0 "exits 0"
assert_match "$OUT" "$WORK/other-place" "points at the existing checkout"
assert_match "$OUT" "skipped" "says it skipped"

test "an existing local branch gets a worktree instead of a skip"
make_repo corebanking-java production
git -C "$WORK/workspace/corebanking-java" branch feature/left-behind origin/production
run_script feature/left-behind corebanking-java
assert_eq "$STATUS" 0 "exits 0"
assert_eq "$(git -C "$WORK/workspace/worktrees/corebanking-java-feature-left-behind" rev-parse --abbrev-ref HEAD 2>/dev/null)" \
  "feature/left-behind" "worktree created on the existing branch"

test "an existing remote branch is adopted without an upstream"
make_repo card-service main
git -C "$WORK/workspace/card-service" branch feature/team-wip origin/main
git -C "$WORK/workspace/card-service" push -q origin feature/team-wip
git -C "$WORK/workspace/card-service" branch -D feature/team-wip >/dev/null
run_script feature/team-wip card-service
assert_eq "$STATUS" 0 "exits 0"
assert_eq "$(git -C "$WORK/workspace/worktrees/card-service-feature-team-wip" rev-parse --abbrev-ref HEAD 2>/dev/null)" \
  "feature/team-wip" "worktree on the pushed branch"
assert_match "$OUT" "upstream none" "reports upstream none"

test "a locally fetched remote branch is preferred over a new branch at the base"
make_repo card-service main
git -C "$WORK/workspace/card-service" branch feature/ahead origin/main
git -C "$WORK/workspace/card-service" push -q origin feature/ahead
git -C "$WORK/workspace/card-service" branch -D feature/ahead >/dev/null
git -C "$WORK/workspace/card-service" fetch -q origin
local_tip=$(git -C "$WORK/workspace/card-service" rev-parse origin/feature/ahead)
run_script feature/ahead card-service
assert_eq "$STATUS" 0 "exits 0"
assert_eq "$(git -C "$WORK/workspace/worktrees/card-service-feature-ahead" rev-parse HEAD 2>/dev/null)" \
  "$local_tip" "worktree at the pushed branch tip"

test "an unreachable origin still creates from the last fetched base"
make_repo corebanking-java production
mv "$WORK/remote-corebanking-java.git" "$WORK/remote-corebanking-java.gone"
run_script fix/offline-branch corebanking-java
assert_eq "$STATUS" 0 "exits 0"
assert_eq "$(git -C "$WORK/workspace/worktrees/corebanking-java-fix-offline-branch" rev-parse --abbrev-ref HEAD 2>/dev/null)" \
  "fix/offline-branch" "worktree created offline"
assert_match "$OUT" "origin is unreachable" "says the base came from the last fetch"

test "unknown repo names fail before anything is created"
make_repo card-service production
run_script fix/typo-in-repo-name card-service card-servcie
assert_eq "$STATUS" 1 "exits 1"
assert_match "$OUT" "card-servcie" "names the missing repo"
[[ -e "$WORK/workspace/worktrees/card-service-fix-typo-in-repo-name" ]] &&
  fail "nothing created when a repo is missing" || ok "nothing created when a repo is missing"

test "--help prints the usage block"
OUT=$(bash "$SCRIPT" --help 2>&1)
STATUS=$?
assert_eq "$STATUS" 0 "exits 0"
assert_match "$OUT" "create-worktree.sh <branch> <repo>" "shows usage"
assert_no_match "$OUT" "set -euo pipefail" "stops at the end of the header"

# --- report ----------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
