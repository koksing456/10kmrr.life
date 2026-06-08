#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
TESTER_ID=""
USES_STRIPE_SUBSCRIPTIONS="unknown"
MACOS_VERSION="unknown"
CPU="unknown"
DISPLAY_SETUP="unknown"
APPROVED="no"
CURRENT_STAGE="requested"
INSTALL_STATUS="not_sent"
KEY_SETUP_STATUS="not_started"
FIRST_MRR_SEEN="unknown"
RETAINED_DAY_7="unknown"
PRO_INTEREST="none"
BLOCKER=""
NEXT_ACTION=""
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 --tester-id ID [options]

Appends one safe alpha-users row to the private ignored alpha tracker:
  build/alpha-tracker/alpha-users.csv

Do not store names, emails, Stripe keys, Stripe object IDs, exact MRR, raw logs,
customer/payment data, or unsanitized screenshots here. Keep identity/contact
mapping outside this repo.

Options:
  --tracker-dir DIR                Tracker directory. Default: build/alpha-tracker.
  --tester-id ID                   Required stable tester id.
  --uses-stripe-subscriptions VAL  yes|no|unknown
  --macos-version VALUE            Non-sensitive version summary, for example 15.5.
  --cpu VALUE                      apple_silicon|intel|unknown
  --display-setup VALUE            built_in|external|multiple|unknown
  --approved VALUE                 yes|no
  --current-stage VALUE            requested|approved|built|configured_key|previewed|installed|saw_mrr|retained_day_7|closed_lost
  --install-status VALUE           not_sent|not_started|in_progress|pass|warn|fail|unknown
  --key-setup-status VALUE         not_started|pass|warn|fail|unknown
  --first-mrr-seen VALUE           yes|no|unknown
  --retained-day-7 VALUE           yes|no|unknown
  --pro-interest VALUE             none|low|medium|high|unknown
  --blocker TEXT                   Short non-sensitive blocker summary.
  --next-action TEXT               Short next action.
  --self-test                      Verify parser, validation, and CSV output.
  --help                           Show this help.
EOF
}

csv_escape() {
  local value="$1"
  value="${value//$'\r'/ }"
  value="${value//$'\n'/ }"
  value="${value//\"/\"\"}"
  printf '"%s"' "$value"
}

validate_safe_text() {
  local label="$1"
  local value="$2"

  if printf '%s\n' "$value" | /usr/bin/grep -Eq '(sk_live_|sk_test_|rk_live_|rk_test_|whsec_)'; then
    printf 'Unsafe %s: contains secret-like token.\n' "$label" >&2
    exit 1
  fi

  if printf '%s\n' "$value" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(tester_XXX|tester_xxx|15\.x|x\.x)([^[:alnum:]_]|$)'; then
    printf 'Unsafe %s: contains placeholder evidence. Use a real stable tester id, a concrete macOS version, or unknown.\n' "$label" >&2
    exit 1
  fi

  if printf '%s\n' "$value" | /usr/bin/grep -Eq '([A-Z]{2,4}\$[0-9][0-9,]*(\.[0-9]{2})?|[A-Z]{3}[[:space:]]+[0-9][0-9,]*(\.[0-9]{2})?|\$[0-9][0-9,]*(\.[0-9]{2})?|([Mm][Rr][Rr]|[Aa][Rr][Rr]|[Rr]evenue|[Aa]mount)[[:space:]:=]+[0-9][0-9,]*(\.[0-9]{2})?)'; then
    printf 'Unsafe %s: contains obvious money amount.\n' "$label" >&2
    exit 1
  fi

  if printf '%s\n' "$value" | /usr/bin/grep -Eq '[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+'; then
    printf 'Unsafe %s: contains email-like contact data. Keep contact mapping outside this repo.\n' "$label" >&2
    exit 1
  fi

  if printf '%s\n' "$value" | /usr/bin/grep -Eq '\b(cus|sub|price|prod|pi|ch|in|cs|pm|seti|si)_[A-Za-z0-9]{8,}\b|client_secret|hosted_invoice_url|invoice_pdf|payment_method|customer_email'; then
    printf 'Unsafe %s: contains Stripe object, customer, invoice, or payment identifiers. Use a non-sensitive summary instead.\n' "$label" >&2
    exit 1
  fi
}

validate_choice() {
  local label="$1"
  local value="$2"
  local allowed="$3"

  if ! printf '%s\n' "$allowed" | /usr/bin/grep -Fxq "$value"; then
    printf 'Invalid %s: %s\nAllowed values:\n%s\n' "$label" "$value" "$allowed" >&2
    exit 64
  fi
}

require_arg() {
  local option="$1"
  if [[ $# -lt 2 || "${2:-}" == --* ]]; then
    printf 'Missing value for %s.\n' "$option" >&2
    exit 64
  fi
}

ensure_tracker() {
  if [[ ! -s "$TRACKER_DIR/alpha-users.csv" ]]; then
    printf 'Alpha users tracker missing. Run ./script/alpha.sh tracker first.\n' >&2
    exit 1
  fi
}

append_user_row() {
  ensure_tracker

  if [[ -z "$TESTER_ID" ]]; then
    printf 'Missing required --tester-id.\n' >&2
    exit 64
  fi

  validate_choice "uses Stripe subscriptions" "$USES_STRIPE_SUBSCRIPTIONS" $'yes\nno\nunknown'
  validate_choice "cpu" "$CPU" $'apple_silicon\nintel\nunknown'
  validate_choice "display setup" "$DISPLAY_SETUP" $'built_in\nexternal\nmultiple\nunknown'
  validate_choice "approved" "$APPROVED" $'yes\nno'
  validate_choice "current stage" "$CURRENT_STAGE" $'requested\napproved\nbuilt\nconfigured_key\npreviewed\ninstalled\nsaw_mrr\nretained_day_7\nclosed_lost'
  validate_choice "install status" "$INSTALL_STATUS" $'not_sent\nnot_started\nin_progress\npass\nwarn\nfail\nunknown'
  validate_choice "key setup status" "$KEY_SETUP_STATUS" $'not_started\npass\nwarn\nfail\nunknown'
  validate_choice "first MRR seen" "$FIRST_MRR_SEEN" $'yes\nno\nunknown'
  validate_choice "retained day 7" "$RETAINED_DAY_7" $'yes\nno\nunknown'
  validate_choice "pro interest" "$PRO_INTEREST" $'none\nlow\nmedium\nhigh\nunknown'

  validate_safe_text "tester id" "$TESTER_ID"
  validate_safe_text "macOS version" "$MACOS_VERSION"
  validate_safe_text "blocker" "$BLOCKER"
  validate_safe_text "next action" "$NEXT_ACTION"

  {
    csv_escape "$TESTER_ID"; printf ','
    csv_escape "$USES_STRIPE_SUBSCRIPTIONS"; printf ','
    csv_escape "$MACOS_VERSION"; printf ','
    csv_escape "$CPU"; printf ','
    csv_escape "$DISPLAY_SETUP"; printf ','
    csv_escape "$APPROVED"; printf ','
    csv_escape "$CURRENT_STAGE"; printf ','
    csv_escape "$INSTALL_STATUS"; printf ','
    csv_escape "$KEY_SETUP_STATUS"; printf ','
    csv_escape "$FIRST_MRR_SEEN"; printf ','
    csv_escape "$RETAINED_DAY_7"; printf ','
    csv_escape "$PRO_INTEREST"; printf ','
    csv_escape "$BLOCKER"; printf ','
    csv_escape "$NEXT_ACTION"; printf '\n'
  } >>"$TRACKER_DIR/alpha-users.csv"

  printf 'Recorded safe alpha user row for tester %s.\n' "$TESTER_ID"
  printf 'Tracker: %s\n' "$TRACKER_DIR/alpha-users.csv"
}

self_test() {
  local temp_dir output live_env
  live_env="live"
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-record-user.XXXXXX)"
  trap 'rm -rf "$temp_dir"' RETURN

  /bin/mkdir -p "$temp_dir/tracker"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/alpha-users.csv" "$temp_dir/tracker/alpha-users.csv"

  output="$("$0" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_001 \
    --uses-stripe-subscriptions yes \
    --macos-version 15.5 \
    --cpu apple_silicon \
    --display-setup built_in \
    --approved yes \
    --current-stage approved \
    --install-status not_started \
    --key-setup-status not_started \
    --first-mrr-seen unknown \
    --retained-day-7 unknown \
    --pro-interest none \
    --next-action 'send invite')"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Recorded safe alpha user row'
  /usr/bin/tail -1 "$temp_dir/tracker/alpha-users.csv" | /usr/bin/grep -q '"tester_001","yes","15.5","apple_silicon"'

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id 'founder@example.com' >/dev/null 2>&1; then
    printf 'record_alpha_user self-test failed: email-like tester id was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_002 --blocker 'MRR US$10,248.00' >/dev/null 2>&1; then
    printf 'record_alpha_user self-test failed: obvious money amount was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_002 --blocker '$10,248.00' >/dev/null 2>&1; then
    printf 'record_alpha_user self-test failed: bare dollar amount was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_003 --blocker "key rk_${live_env}_1234567890abcdef" >/dev/null 2>&1; then
    printf 'record_alpha_user self-test failed: secret-like token was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_004 --blocker 'customer cus_1234567890abcdef shared raw response' >/dev/null 2>&1; then
    printf 'record_alpha_user self-test failed: Stripe object id was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_XXX >/dev/null 2>&1; then
    printf 'record_alpha_user self-test failed: placeholder tester id was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_005 --macos-version 15.x >/dev/null 2>&1; then
    printf 'record_alpha_user self-test failed: placeholder macOS version was accepted.\n' >&2
    exit 1
  fi

  printf 'Alpha user recorder self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracker-dir) require_arg "$1" "${2:-}"; TRACKER_DIR="$2"; shift 2 ;;
    --tester-id) require_arg "$1" "${2:-}"; TESTER_ID="$2"; shift 2 ;;
    --uses-stripe-subscriptions) require_arg "$1" "${2:-}"; USES_STRIPE_SUBSCRIPTIONS="$2"; shift 2 ;;
    --macos-version) require_arg "$1" "${2:-}"; MACOS_VERSION="$2"; shift 2 ;;
    --cpu) require_arg "$1" "${2:-}"; CPU="$2"; shift 2 ;;
    --display-setup) require_arg "$1" "${2:-}"; DISPLAY_SETUP="$2"; shift 2 ;;
    --approved) require_arg "$1" "${2:-}"; APPROVED="$2"; shift 2 ;;
    --current-stage) require_arg "$1" "${2:-}"; CURRENT_STAGE="$2"; shift 2 ;;
    --install-status) require_arg "$1" "${2:-}"; INSTALL_STATUS="$2"; shift 2 ;;
    --key-setup-status) require_arg "$1" "${2:-}"; KEY_SETUP_STATUS="$2"; shift 2 ;;
    --first-mrr-seen) require_arg "$1" "${2:-}"; FIRST_MRR_SEEN="$2"; shift 2 ;;
    --retained-day-7) require_arg "$1" "${2:-}"; RETAINED_DAY_7="$2"; shift 2 ;;
    --pro-interest) require_arg "$1" "${2:-}"; PRO_INTEREST="$2"; shift 2 ;;
    --blocker) require_arg "$1" "${2:-}"; BLOCKER="$2"; shift 2 ;;
    --next-action) require_arg "$1" "${2:-}"; NEXT_ACTION="$2"; shift 2 ;;
    --self-test) SELF_TEST=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
done

if [[ "$SELF_TEST" == "true" ]]; then
  self_test
  exit 0
fi

append_user_row
