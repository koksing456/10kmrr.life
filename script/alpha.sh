#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<EOF
Usage: $0 COMMAND [options]

Unified private alpha operator entrypoint. This script delegates to the
existing focused alpha scripts and does not print Stripe keys, MRR values, raw
logs, raw Stripe responses, customer/payment data, or contact data.

Commands:
  status    Print alpha status summary.
  next      Print one recommended next action.
  report    Write the private readiness report under build/.
  tracker   Prepare or refresh the private tracker workspace.
  invite    Prepare an approved tester invite packet.
  start     Start guided alpha setup for a tester.
  success   Record successful install and Lock Screen compatibility evidence.
  support   Record a common safe support issue packet.
  day7      Record Day 7 retention and Pro signal.
  weekly    Print safe weekly aggregate summary.
  audit     Audit private tracker rows for unsafe fields.

Examples:
  $0 next
  $0 invite --tester-id tester_001 --macos-version 15.5 --cpu apple_silicon --display-setup built_in
  $0 start --tester-id tester_001
  $0 success --tester-id tester_001 --macos-version 15.5 --cpu apple_silicon --display-setup built_in

Use '$0 COMMAND --help' for command-specific options.
EOF
}

command_script() {
  case "$1" in
    status) printf '%s\n' "$ROOT_DIR/script/alpha_status.sh" ;;
    next) printf '%s\n' "$ROOT_DIR/script/alpha_next_action.sh" ;;
    report) printf '%s\n' "$ROOT_DIR/script/alpha_readiness_report.sh" ;;
    tracker) printf '%s\n' "$ROOT_DIR/script/prepare_alpha_tracker.sh" ;;
    invite) printf '%s\n' "$ROOT_DIR/script/prepare_alpha_invite_packet.sh" ;;
    start) printf '%s\n' "$ROOT_DIR/script/start_alpha.sh" ;;
    success) printf '%s\n' "$ROOT_DIR/script/record_alpha_success.sh" ;;
    support) printf '%s\n' "$ROOT_DIR/script/record_alpha_support_issue.sh" ;;
    day7) printf '%s\n' "$ROOT_DIR/script/record_alpha_day7.sh" ;;
    weekly) printf '%s\n' "$ROOT_DIR/script/alpha_weekly_summary.sh" ;;
    audit) printf '%s\n' "$ROOT_DIR/script/audit_alpha_tracker.sh" ;;
    *) return 1 ;;
  esac
}

self_test() {
  local temp_dir output
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-alpha-cli.XXXXXX)"
  trap 'rm -rf "$temp_dir"' RETURN

  /bin/mkdir -p "$temp_dir/tracker"
  /bin/cp "$ROOT_DIR"/docs/alpha/templates/*.csv "$temp_dir/tracker/"

  output="$("$0" next --tracker-dir "$temp_dir/tracker" --no-signing)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'prepare the first alpha invite packet'

  output="$("$0" status --no-network)"
  printf '%s\n' "$output" | /usr/bin/grep -q '10kmrr.life alpha status'

  output="$("$0" invite --tracker-dir "$temp_dir/tracker" --output-dir "$temp_dir/invites" --tester-id tester_001 --macos-version 15.5 --cpu apple_silicon --display-setup built_in)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Prepared safe alpha invite packet'
  test -s "$temp_dir/invites/tester_001.md"

  if "$0" nope >/dev/null 2>&1; then
    printf 'alpha self-test failed: unknown command was accepted.\n' >&2
    exit 1
  fi

  if printf '%s\n' "$output" | /usr/bin/grep -Eq '(sk_live_|sk_test_|rk_live_|rk_test_|whsec_)'; then
    printf 'alpha self-test failed: output contained a secret-like token.\n' >&2
    exit 1
  fi

  printf 'Alpha CLI self-test passed.\n'
}

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 64
fi

case "$1" in
  --help|-h)
    usage
    exit 0
    ;;
  --self-test)
    self_test
    exit 0
    ;;
esac

COMMAND="$1"
shift

if ! SCRIPT_PATH="$(command_script "$COMMAND")"; then
  printf 'Unknown alpha command: %s\n\n' "$COMMAND" >&2
  usage >&2
  exit 64
fi

exec "$SCRIPT_PATH" "$@"
