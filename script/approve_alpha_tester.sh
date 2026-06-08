#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
TESTER_ID=""
USES_STRIPE_SUBSCRIPTIONS="yes"
MACOS_VERSION="unknown"
CPU="unknown"
DISPLAY_SETUP="unknown"
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 --tester-id ID [options]

Records an approved alpha tester in the private ignored tracker and prints the
safe invite generator command for that tester. Keep identity/contact mapping outside this
repo.

Options:
  --tracker-dir DIR                Tracker directory. Default: build/alpha-tracker.
  --tester-id ID                   Required stable private tester id.
  --uses-stripe-subscriptions VAL  yes|no|unknown. Default: yes.
  --macos-version VALUE            Non-sensitive version summary, for example 15.5.
  --cpu VALUE                      apple_silicon|intel|unknown.
  --display-setup VALUE            built_in|external|multiple|clamshell|unknown.
  --self-test                      Verify wrapper behavior in a temporary tracker.
  --help                           Show this help.
EOF
}

require_arg() {
  local option="$1"
  if [[ $# -lt 2 || "${2:-}" == --* ]]; then
    printf 'Missing value for %s.\n' "$option" >&2
    exit 64
  fi
}

shell_quote() {
  local value="$1"
  printf "'%s'" "${value//\'/\'\\\'\'}"
}

validate_write_values() {
  if printf '%s\n%s\n' "$TESTER_ID" "$MACOS_VERSION" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(tester_XXX|tester_xxx|15\.x|x\.x)([^[:alnum:]_]|$)'; then
    printf 'Approved tester write mode needs real evidence values. Replace tester_XXX and 15.x placeholders before writing tracker rows.\n' >&2
    exit 64
  fi
}

record_approved_tester() {
  "$ROOT_DIR/script/record_alpha_user.sh" \
    --tracker-dir "$TRACKER_DIR" \
    --tester-id "$TESTER_ID" \
    --uses-stripe-subscriptions "$USES_STRIPE_SUBSCRIPTIONS" \
    --macos-version "$MACOS_VERSION" \
    --cpu "$CPU" \
    --display-setup "$DISPLAY_SETUP" \
    --approved yes \
    --current-stage approved \
    --install-status not_sent \
    --key-setup-status not_started \
    --first-mrr-seen unknown \
    --retained-day-7 unknown \
    --pro-interest none \
    --next-action "send invite"
}

print_invite() {
  cat <<EOF

Send this setup path to the approved tester:

./script/alpha.sh start --tester-id $(shell_quote "$TESTER_ID")

Or generate the full safe invite message:

./script/alpha.sh invite --tester-id $(shell_quote "$TESTER_ID") --macos-version $(shell_quote "$MACOS_VERSION") --cpu $(shell_quote "$CPU") --display-setup $(shell_quote "$DISPLAY_SETUP") --dry-run

Before setup, remind them:
- Read SECURITY.md.
- Use a restricted read-only Stripe key, not a full-access secret key.
- Enter the key only in the macOS setup window.
- Do not send Stripe keys, Stripe object IDs, exact MRR, raw Stripe responses, raw logs, customer/payment data, or unsanitized screenshots.

If setup fails, ask for:

./script/alpha.sh support-report

Share only the sanitized support report summary or the failing section name.
EOF
}

approve_tester() {
  if [[ -z "$TESTER_ID" ]]; then
    printf 'Missing required --tester-id.\n' >&2
    exit 64
  fi

  validate_write_values
  record_approved_tester
  print_invite
}

self_test() {
  local temp_dir output live_env
  live_env="live"
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-approve-alpha.XXXXXX)"
  trap 'rm -rf "$temp_dir"' RETURN

  /bin/mkdir -p "$temp_dir/tracker"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/alpha-users.csv" "$temp_dir/tracker/alpha-users.csv"

  output="$("$0" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_001 \
    --macos-version 15.5 \
    --cpu apple_silicon \
    --display-setup built_in)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Recorded safe alpha user row'
  printf '%s\n' "$output" | /usr/bin/grep -q "./script/alpha.sh start --tester-id 'tester_001'"
  printf '%s\n' "$output" | /usr/bin/grep -q "./script/alpha.sh invite --tester-id 'tester_001' --macos-version '15.5' --cpu 'apple_silicon' --display-setup 'built_in' --dry-run"
  /usr/bin/tail -1 "$temp_dir/tracker/alpha-users.csv" | /usr/bin/grep -q '"tester_001","yes","15.5","apple_silicon","built_in","yes","approved"'

  output="$("$0" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_006 \
    --macos-version 15.5 \
    --cpu apple_silicon \
    --display-setup clamshell)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Recorded safe alpha user row'
  /usr/bin/tail -1 "$temp_dir/tracker/alpha-users.csv" | /usr/bin/grep -q '"tester_006","yes","15.5","apple_silicon","clamshell","yes","approved"'

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id 'founder@example.com' >/dev/null 2>&1; then
    printf 'approve_alpha_tester self-test failed: email-like tester id was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id "rk_${live_env}_1234567890abcdef" >/dev/null 2>&1; then
    printf 'approve_alpha_tester self-test failed: secret-like tester id was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_XXX --macos-version 15.5 >/dev/null 2>&1; then
    printf 'approve_alpha_tester self-test failed: placeholder tester id was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_005 --macos-version 15.x >/dev/null 2>&1; then
    printf 'approve_alpha_tester self-test failed: placeholder macOS version was accepted.\n' >&2
    exit 1
  fi

  if printf '%s\n' "$output" | /usr/bin/grep -Eq '(sk_live_|sk_test_|rk_live_|rk_test_|whsec_)'; then
    printf 'approve_alpha_tester self-test failed: output contained a secret-like token.\n' >&2
    exit 1
  fi

  printf 'Alpha tester approval wrapper self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracker-dir) require_arg "$1" "${2:-}"; TRACKER_DIR="$2"; shift 2 ;;
    --tester-id) require_arg "$1" "${2:-}"; TESTER_ID="$2"; shift 2 ;;
    --uses-stripe-subscriptions) require_arg "$1" "${2:-}"; USES_STRIPE_SUBSCRIPTIONS="$2"; shift 2 ;;
    --macos-version) require_arg "$1" "${2:-}"; MACOS_VERSION="$2"; shift 2 ;;
    --cpu) require_arg "$1" "${2:-}"; CPU="$2"; shift 2 ;;
    --display-setup) require_arg "$1" "${2:-}"; DISPLAY_SETUP="$2"; shift 2 ;;
    --self-test) SELF_TEST=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
done

if [[ "$SELF_TEST" == "true" ]]; then
  self_test
  exit 0
fi

approve_tester
