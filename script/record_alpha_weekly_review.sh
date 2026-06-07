#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
WEEK_START="$(/bin/date '+%Y-%m-%d')"
SUPPORT_LOAD="unknown"
SETUP_FAILURE_RATE="unknown"
RETENTION_COUNT="0"
PRO_SIGNAL_COUNT="0"
COMPATIBILITY_FAILURES="0"
SECRET_SHARING_RISK="none"
SCOPE_PULL="none"
DECISION="continue"
NEXT_ACTION=""
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 [options]

Appends one safe weekly-review row to the private ignored alpha tracker:
  build/alpha-tracker/weekly-review.csv

Use only aggregate non-sensitive values. Do not include tester identity,
contact details, exact MRR, raw logs, raw Stripe responses, or screenshots.

Options:
  --tracker-dir DIR             Tracker directory. Default: build/alpha-tracker.
  --week-start YYYY-MM-DD       Week start date. Default: today.
  --support-load VALUE          unknown|low|medium|high
  --setup-failure-rate VALUE    unknown|low|medium|high
  --retention-count NUMBER      Non-negative integer.
  --pro-signal-count NUMBER     Non-negative integer.
  --compatibility-failures NUM  Non-negative integer.
  --secret-sharing-risk VALUE   none|low|medium|high
  --scope-pull VALUE            none|low|medium|high
  --decision VALUE              continue|pause|narrow|prepare_beta|stop
  --next-action TEXT            Short non-sensitive next action.
  --self-test                   Verify parser, validation, and CSV output.
  --help                        Show this help.
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

validate_non_negative_integer() {
  local label="$1"
  local value="$2"

  if ! printf '%s\n' "$value" | /usr/bin/grep -Eq '^[0-9]+$'; then
    printf 'Invalid %s: %s. Use a non-negative integer.\n' "$label" "$value" >&2
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
  if [[ ! -s "$TRACKER_DIR/weekly-review.csv" ]]; then
    printf 'Weekly review tracker missing. Run ./script/prepare_alpha_tracker.sh first.\n' >&2
    exit 1
  fi
}

append_weekly_row() {
  ensure_tracker

  if ! printf '%s\n' "$WEEK_START" | /usr/bin/grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    printf 'Invalid week start: %s. Use YYYY-MM-DD.\n' "$WEEK_START" >&2
    exit 64
  fi

  validate_choice "support load" "$SUPPORT_LOAD" $'unknown\nlow\nmedium\nhigh'
  validate_choice "setup failure rate" "$SETUP_FAILURE_RATE" $'unknown\nlow\nmedium\nhigh'
  validate_choice "secret sharing risk" "$SECRET_SHARING_RISK" $'none\nlow\nmedium\nhigh'
  validate_choice "scope pull" "$SCOPE_PULL" $'none\nlow\nmedium\nhigh'
  validate_choice "decision" "$DECISION" $'continue\npause\nnarrow\nprepare_beta\nstop'
  validate_non_negative_integer "retention count" "$RETENTION_COUNT"
  validate_non_negative_integer "Pro signal count" "$PRO_SIGNAL_COUNT"
  validate_non_negative_integer "compatibility failures" "$COMPATIBILITY_FAILURES"
  validate_safe_text "next action" "$NEXT_ACTION"

  {
    csv_escape "$WEEK_START"; printf ','
    csv_escape "$SUPPORT_LOAD"; printf ','
    csv_escape "$SETUP_FAILURE_RATE"; printf ','
    csv_escape "$RETENTION_COUNT"; printf ','
    csv_escape "$PRO_SIGNAL_COUNT"; printf ','
    csv_escape "$COMPATIBILITY_FAILURES"; printf ','
    csv_escape "$SECRET_SHARING_RISK"; printf ','
    csv_escape "$SCOPE_PULL"; printf ','
    csv_escape "$DECISION"; printf ','
    csv_escape "$NEXT_ACTION"; printf '\n'
  } >>"$TRACKER_DIR/weekly-review.csv"

  printf 'Recorded safe weekly alpha review for %s.\n' "$WEEK_START"
  printf 'Tracker: %s\n' "$TRACKER_DIR/weekly-review.csv"
}

self_test() {
  local temp_dir output live_env
  live_env="live"
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-record-weekly.XXXXXX)"
  trap 'rm -rf "$temp_dir"' RETURN

  /bin/mkdir -p "$temp_dir/tracker"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/weekly-review.csv" "$temp_dir/tracker/weekly-review.csv"

  output="$("$0" \
    --tracker-dir "$temp_dir/tracker" \
    --week-start 2026-06-08 \
    --support-load low \
    --setup-failure-rate low \
    --retention-count 2 \
    --pro-signal-count 1 \
    --compatibility-failures 0 \
    --secret-sharing-risk none \
    --scope-pull low \
    --decision continue \
    --next-action 'invite next tester')"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Recorded safe weekly alpha review'
  /usr/bin/tail -1 "$temp_dir/tracker/weekly-review.csv" | /usr/bin/grep -q '"2026-06-08","low","low","2","1","0"'

  if "$0" --tracker-dir "$temp_dir/tracker" --week-start 2026-06-08 --retention-count two >/dev/null 2>&1; then
    printf 'record_alpha_weekly_review self-test failed: invalid count was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --week-start 2026-06-08 --next-action 'MRR US$10,248.00' >/dev/null 2>&1; then
    printf 'record_alpha_weekly_review self-test failed: obvious money amount was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --week-start 2026-06-08 --next-action '$10,248.00' >/dev/null 2>&1; then
    printf 'record_alpha_weekly_review self-test failed: bare dollar amount was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --week-start 2026-06-08 --next-action "key rk_${live_env}_1234567890abcdef" >/dev/null 2>&1; then
    printf 'record_alpha_weekly_review self-test failed: secret-like token was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --week-start 2026-06-08 --next-action 'email founder@example.com' >/dev/null 2>&1; then
    printf 'record_alpha_weekly_review self-test failed: email-like next action was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --week-start 2026-06-08 --next-action 'raw customer cus_1234567890abcdef in support notes' >/dev/null 2>&1; then
    printf 'record_alpha_weekly_review self-test failed: Stripe object id was accepted.\n' >&2
    exit 1
  fi

  printf 'Alpha weekly review recorder self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracker-dir) require_arg "$1" "${2:-}"; TRACKER_DIR="$2"; shift 2 ;;
    --week-start) require_arg "$1" "${2:-}"; WEEK_START="$2"; shift 2 ;;
    --support-load) require_arg "$1" "${2:-}"; SUPPORT_LOAD="$2"; shift 2 ;;
    --setup-failure-rate) require_arg "$1" "${2:-}"; SETUP_FAILURE_RATE="$2"; shift 2 ;;
    --retention-count) require_arg "$1" "${2:-}"; RETENTION_COUNT="$2"; shift 2 ;;
    --pro-signal-count) require_arg "$1" "${2:-}"; PRO_SIGNAL_COUNT="$2"; shift 2 ;;
    --compatibility-failures) require_arg "$1" "${2:-}"; COMPATIBILITY_FAILURES="$2"; shift 2 ;;
    --secret-sharing-risk) require_arg "$1" "${2:-}"; SECRET_SHARING_RISK="$2"; shift 2 ;;
    --scope-pull) require_arg "$1" "${2:-}"; SCOPE_PULL="$2"; shift 2 ;;
    --decision) require_arg "$1" "${2:-}"; DECISION="$2"; shift 2 ;;
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

append_weekly_row
