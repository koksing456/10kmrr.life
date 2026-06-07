#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=false

usage() {
  cat <<EOF
Usage: $0 [--dry-run] [--self-test] [--help]

Rebuilds the app and reinstalls the LaunchAgent while preserving the Stripe
Keychain entry, local MRR cache, and display settings.

Options:
  --dry-run    Print the repair steps without changing local state.
  --self-test  Validate repair command planning without changing local state.
  --help       Show this help.
EOF
}

run_step() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf 'DRY-RUN  %s\n' "$*"
  else
    "$@"
  fi
}

self_test() {
  local output
  output="$("$0" --dry-run 2>&1)"

  printf '%s\n' "$output" | /usr/bin/grep -q 'DRY-RUN  .*/script/diagnose.sh'
  printf '%s\n' "$output" | /usr/bin/grep -q 'DRY-RUN  .*/script/uninstall_lock_overlay_agent.sh'
  printf '%s\n' "$output" | /usr/bin/grep -q 'DRY-RUN  .*/script/install_lock_overlay_agent.sh'
  printf '%s\n' "$output" | /usr/bin/grep -q 'Repair keeps Keychain, cache, and display settings.'

  if printf '%s\n' "$output" | /usr/bin/grep -Eq -- '--all|--keychain|--local-data'; then
    printf 'repair self-test failed: repair plan would remove local data or Keychain.\n' >&2
    exit 1
  fi

  printf 'repair self-test passed.\n'
}

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=true
      ;;
    --self-test)
      self_test
      exit 0
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 64
      ;;
  esac
done

cd "$ROOT_DIR"

printf 'Repair keeps Keychain, cache, and display settings.\n'
printf 'Before repair diagnostic:\n'
run_step "$ROOT_DIR/script/diagnose.sh"

printf '\nReinstalling app and LaunchAgent...\n'
run_step "$ROOT_DIR/script/uninstall_lock_overlay_agent.sh"
run_step "$ROOT_DIR/script/install_lock_overlay_agent.sh"

printf '\nAfter repair diagnostic:\n'
run_step "$ROOT_DIR/script/diagnose.sh"
