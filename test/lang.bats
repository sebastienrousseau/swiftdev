#!/usr/bin/env bats
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Unit tests for dotfiles.d/swift.sh — the Swift language profile fragment
# installed to /etc/profile.d and sourced by login shells. The Swift toolchain
# already lives at /usr/bin in the base image; the fragment defensively ensures
# that prefix is on PATH (guarded, so it is safe to re-source). These tests
# source it in a hermetic sandbox and assert it does so without error and is
# idempotent.
load helpers/common

setup() { common_setup; }

SCRIPT="dotfiles.d/swift.sh"

@test "swift.sh: ensures the toolchain prefix is on PATH" {
  run bash -c '
    set -euo pipefail
    export PATH="/langdev-base"
    # shellcheck source=/dev/null
    source "$1"
    printf "PATHVAL=%s\n" "$PATH"
  ' _ "$REPO_ROOT/$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PATHVAL=/usr/bin:/langdev-base"* ]]
}

@test "swift.sh: is idempotent — re-sourcing does not duplicate the PATH entry" {
  run bash -c '
    set -euo pipefail
    export PATH="/langdev-base"
    source "$1"; source "$1"
    printf "PATHVAL=%s" "$PATH"
  ' _ "$REPO_ROOT/$SCRIPT"
  [ "$status" -eq 0 ]
  pathval="${output#PATHVAL=}"
  n="$(printf '%s' "$pathval" | grep -oF '/usr/bin' | wc -l)"
  [ "$n" -eq 1 ]
}
