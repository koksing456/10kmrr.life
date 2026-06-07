#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
ATTEMPT_DATE="$(/bin/date '+%Y-%m-%d')"
TESTER_ID=""
STAGE="requested"
BUILD_VERIFY="not_run"
CONFIGURED_KEY="no"
PREVIEWED="no"
INSTALLED="no"
SAW_MRR="no"
DIAGNOSE_SUMMARY="not_collected"
BLOCKER=""
NEXT_ACTION=""
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 --tester-id ID [options]

Appends one safe install-funnel row to the private ignored alpha tracker:
  build/alpha-tracker/install-funnel.csv

This script rejects Stripe-key-like strings, Stripe object IDs, raw Stripe
fields, contact-like data, and obvious money amounts. It is for pass/warn/fail
summaries only, not raw logs or exact MRR.

Options:
  --tracker-dir DIR          Tracker directory. Default: build/alpha-tracker.
  --attempt-date YYYY-MM-DD  Attempt date. Default: today.
  --tester-id ID             Required stable tester id.
  --stage VALUE              requested|approved|built|configured_key|previewed|installed|saw_mrr|retained_day_7|closed_lost
  --build-verify VALUE       not_run|pass|warn|fail
  --configured-key VALUE     yes|no|unknown
  --previewed VALUE          yes|no|unknown
  --installed VALUE          yes|no|unknown
  --saw-mrr VALUE            yes|no|unknown
  --diagnose-summary TEXT    Short pass/warn/fail summary, no raw logs.
  --blocker TEXT             Short non-sensitive blocker summary.
  --next-action TEXT         Short next action.
  --self-test                Verify parser, validation, and CSV output.
  --help                     Show this help.
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
    printf 'Unsafe %s: contains obvious money amount. Use yes/no or a sanitized range instead.\n' "$label" >&2
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
  if [[ ! -s "$TRACKER_DIR/install-funnel.csv" ]]; then
    printf 'Install tracker missing. Run ./script/prepare_alpha_tracker.sh first.\n' >&2
    exit 1
  fi
}

append_install_row() {
  ensure_tracker

  if [[ -z "$TESTER_ID" ]]; then
    printf 'Missing required --tester-id.\n' >&2
    exit 64
  fi

  validate_choice "stage" "$STAGE" $'requested\napproved\nbuilt\nconfigured_key\npreviewed\ninstalled\nsaw_mrr\nretained_day_7\nclosed_lost'
  validate_choice "build verify" "$BUILD_VERIFY" $'not_run\npass\nwarn\nfail'
  validate_choice "configured key" "$CONFIGURED_KEY" $'yes\nno\nunknown'
  validate_choice "previewed" "$PREVIEWED" $'yes\nno\nunknown'
  validate_choice "installed" "$INSTALLED" $'yes\nno\nunknown'
  validate_choice "saw mrr" "$SAW_MRR" $'yes\nno\nunknown'

  if ! printf '%s\n' "$ATTEMPT_DATE" | /usr/bin/grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    printf 'Invalid attempt date: %s. Use YYYY-MM-DD.\n' "$ATTEMPT_DATE" >&2
    exit 64
  fi

  validate_safe_text "tester id" "$TESTER_ID"
  validate_safe_text "diagnose summary" "$DIAGNOSE_SUMMARY"
  validate_safe_text "blocker" "$BLOCKER"
  validate_safe_text "next action" "$NEXT_ACTION"

  {
    csv_escape "$TESTER_ID"; printf ','
    csv_escape "$ATTEMPT_DATE"; printf ','
    csv_escape "$STAGE"; printf ','
    csv_escape "$BUILD_VERIFY"; printf ','
    csv_escape "$CONFIGURED_KEY"; printf ','
    csv_escape "$PREVIEWED"; printf ','
    csv_escape "$INSTALLED"; printf ','
    csv_escape "$SAW_MRR"; printf ','
    csv_escape "$DIAGNOSE_SUMMARY"; printf ','
    csv_escape "$BLOCKER"; printf ','
    csv_escape "$NEXT_ACTION"; printf '\n'
  } >>"$TRACKER_DIR/install-funnel.csv"

  printf 'Recorded safe install evidence for tester %s.\n' "$TESTER_ID"
  printf 'Tracker: %s\n' "$TRACKER_DIR/install-funnel.csv"
}

self_test() {
  local temp_dir output live_env
  live_env="live"
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-record-alpha.XXXXXX)"
  trap 'rm -rf "$temp_dir"' RETURN

  /bin/mkdir -p "$temp_dir/tracker"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/install-funnel.csv" "$temp_dir/tracker/install-funnel.csv"

  output="$("$0" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_001 \
    --attempt-date 2026-06-08 \
    --stage installed \
    --build-verify pass \
    --configured-key yes \
    --previewed yes \
    --installed yes \
    --saw-mrr yes \
    --diagnose-summary 'PASS summary only' \
    --blocker '' \
    --next-action 'day 7 follow-up')"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Recorded safe install evidence'
  /usr/bin/tail -1 "$temp_dir/tracker/install-funnel.csv" | /usr/bin/grep -q '"tester_001","2026-06-08","installed","pass","yes","yes","yes","yes"'

  if "$0" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_002 \
    --diagnose-summary 'MRR was US$10,248.00' >/dev/null 2>&1; then
    printf 'record_alpha_install self-test failed: obvious money amount was accepted.\n' >&2
    exit 1
  fi

  if "$0" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_002 \
    --diagnose-summary 'MRR 10248.00' >/dev/null 2>&1; then
    printf 'record_alpha_install self-test failed: MRR-labelled money amount was accepted.\n' >&2
    exit 1
  fi

  if "$0" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id 'founder@example.com' >/dev/null 2>&1; then
    printf 'record_alpha_install self-test failed: email-like tester id was accepted.\n' >&2
    exit 1
  fi

  if "$0" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_003 \
    --diagnose-summary "key rk_${live_env}_1234567890abcdef" >/dev/null 2>&1; then
    printf 'record_alpha_install self-test failed: secret-like token was accepted.\n' >&2
    exit 1
  fi

  if "$0" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_004 \
    --diagnose-summary 'raw subscription sub_1234567890abcdef' >/dev/null 2>&1; then
    printf 'record_alpha_install self-test failed: Stripe object id was accepted.\n' >&2
    exit 1
  fi

  if "$0" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_XXX >/dev/null 2>&1; then
    printf 'record_alpha_install self-test failed: placeholder tester id was accepted.\n' >&2
    exit 1
  fi

  printf 'Alpha install evidence recorder self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracker-dir)
      require_arg "$1" "${2:-}"
      TRACKER_DIR="$2"
      shift 2
      ;;
    --attempt-date)
      require_arg "$1" "${2:-}"
      ATTEMPT_DATE="$2"
      shift 2
      ;;
    --tester-id)
      require_arg "$1" "${2:-}"
      TESTER_ID="$2"
      shift 2
      ;;
    --stage)
      require_arg "$1" "${2:-}"
      STAGE="$2"
      shift 2
      ;;
    --build-verify)
      require_arg "$1" "${2:-}"
      BUILD_VERIFY="$2"
      shift 2
      ;;
    --configured-key)
      require_arg "$1" "${2:-}"
      CONFIGURED_KEY="$2"
      shift 2
      ;;
    --previewed)
      require_arg "$1" "${2:-}"
      PREVIEWED="$2"
      shift 2
      ;;
    --installed)
      require_arg "$1" "${2:-}"
      INSTALLED="$2"
      shift 2
      ;;
    --saw-mrr)
      require_arg "$1" "${2:-}"
      SAW_MRR="$2"
      shift 2
      ;;
    --diagnose-summary)
      require_arg "$1" "${2:-}"
      DIAGNOSE_SUMMARY="$2"
      shift 2
      ;;
    --blocker)
      require_arg "$1" "${2:-}"
      BLOCKER="$2"
      shift 2
      ;;
    --next-action)
      require_arg "$1" "${2:-}"
      NEXT_ACTION="$2"
      shift 2
      ;;
    --self-test)
      SELF_TEST=true
      shift
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

if [[ "$SELF_TEST" == "true" ]]; then
  self_test
  exit 0
fi

append_install_row
