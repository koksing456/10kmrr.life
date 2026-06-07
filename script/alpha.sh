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
  check     Run the full public-alpha repo gate and signing preflight.
  tracker   Prepare or refresh the private tracker workspace.
  invite    Prepare an approved tester invite packet.
  start     Start guided alpha setup for a tester.
  success   Record successful install and Lock Screen compatibility evidence.
  support   Record a common safe support issue packet.
  day7      Record Day 7 retention and Pro signal.
  weekly    Print safe weekly aggregate summary.
  review    Record one safe aggregate weekly review row.
  audit     Audit private tracker rows for unsafe fields.
  smoke     Preview or run guarded local smoke checks.
  support-report
           Generate a sanitized local support report.
  signing   Check Developer ID and notary prerequisites.
  beta-ready
           Check private beta evidence and signing readiness.
  package   Build a gated private beta package.
  labels    Preview or apply GitHub issue labels from .github/labels.yml.

Examples:
  $0 next
  $0 invite --tester-id tester_XXX --macos-version 15.x --cpu apple_silicon --display-setup built_in --dry-run
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
    check) printf '%s\n' "$ROOT_DIR/script/check.sh" ;;
    tracker) printf '%s\n' "$ROOT_DIR/script/prepare_alpha_tracker.sh" ;;
    invite) printf '%s\n' "$ROOT_DIR/script/prepare_alpha_invite_packet.sh" ;;
    start) printf '%s\n' "$ROOT_DIR/script/start_alpha.sh" ;;
    success) printf '%s\n' "$ROOT_DIR/script/record_alpha_success.sh" ;;
    support) printf '%s\n' "$ROOT_DIR/script/record_alpha_support_issue.sh" ;;
    day7) printf '%s\n' "$ROOT_DIR/script/record_alpha_day7.sh" ;;
    weekly) printf '%s\n' "$ROOT_DIR/script/alpha_weekly_summary.sh" ;;
    review) printf '%s\n' "$ROOT_DIR/script/record_alpha_weekly_review.sh" ;;
    audit) printf '%s\n' "$ROOT_DIR/script/audit_alpha_tracker.sh" ;;
    smoke) printf '%s\n' "$ROOT_DIR/script/run_local_smoke.sh" ;;
    support-report) printf '%s\n' "$ROOT_DIR/script/support_report.sh" ;;
    signing) printf '%s\n' "$ROOT_DIR/script/signing_preflight.sh" ;;
    beta-ready) printf '%s\n' "$ROOT_DIR/script/private_beta_readiness.sh" ;;
    package) printf '%s\n' "$ROOT_DIR/script/package_private_beta.sh" ;;
    labels) printf '%s\n' "$ROOT_DIR/script/sync_github_labels.sh" ;;
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
  printf '%s\n' "$output" | /usr/bin/grep -q 'preview the first alpha invite packet without writing evidence'
  printf '%s\n' "$output" | /usr/bin/grep -q -- '--dry-run'

  output="$("$0" status --no-network)"
  printf '%s\n' "$output" | /usr/bin/grep -q '10kmrr.life alpha status'

  output="$("$0" signing --self-test)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Signing preflight self-test passed'

  output="$("$0" beta-ready --self-test)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Private beta readiness self-test passed'

  output="$("$0" review --self-test)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Alpha weekly review recorder self-test passed'

  output="$("$0" smoke --self-test)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Local smoke runner self-test passed'

  output="$("$0" support-report --self-test)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Support report redaction self-test passed'

  output="$("$0" labels --self-test)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'GitHub label sync self-test passed'

  output="$("$0" invite --tracker-dir "$temp_dir/tracker" --output-dir "$temp_dir/invites" --tester-id tester_001 --macos-version 15.5 --cpu apple_silicon --display-setup built_in)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Prepared safe alpha invite packet'
  test -s "$temp_dir/invites/tester_001.md"

  output="$("$0" invite --tracker-dir "$temp_dir/tracker" --output-dir "$temp_dir/dry-run-invites" --tester-id tester_002 --macos-version 15.5 --cpu apple_silicon --display-setup built_in --dry-run)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'DRY RUN: no tracker row or invite file was written'
  test ! -e "$temp_dir/dry-run-invites/tester_002.md"

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
