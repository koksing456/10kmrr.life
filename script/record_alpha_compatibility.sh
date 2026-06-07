#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
TESTER_ID=""
CHECK_DATE="$(/bin/date '+%Y-%m-%d')"
MACOS_VERSION="unknown"
CPU="unknown"
DISPLAY_SETUP="unknown"
BUILD_VERIFY="not_run"
PREVIEW_GLASS="unknown"
LOCK_SCREEN_VISIBLE="unknown"
UNLOCK_HIDES_OVERLAY="unknown"
LAUNCHAGENT_STABLE="unknown"
RESULT="warn"
BLOCKER=""
NEXT_ACTION=""
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 --tester-id ID [options]

Appends one safe compatibility row to the private ignored alpha tracker:
  build/alpha-tracker/compatibility.csv

Track only pass/warn/fail compatibility evidence. Do not include Stripe keys,
exact MRR, raw logs, raw Stripe responses, customer/payment data, contact
details, or unsanitized screenshots.

Options:
  --tracker-dir DIR              Tracker directory. Default: build/alpha-tracker.
  --tester-id ID                 Required stable tester id.
  --check-date YYYY-MM-DD        Check date. Default: today.
  --macos-version VALUE          Non-sensitive version summary, for example 15.5.
  --cpu VALUE                    apple_silicon|intel|unknown
  --display-setup VALUE          built_in|external|multiple|clamshell|unknown
  --build-verify VALUE           not_run|pass|warn|fail
  --preview-glass VALUE          unknown|not_run|private|fallback|fail
  --lock-screen-visible VALUE    yes|no|unknown
  --unlock-hides-overlay VALUE   yes|no|unknown
  --launchagent-stable VALUE     yes|no|unknown
  --result VALUE                 pass|warn|fail
  --blocker TEXT                 Short non-sensitive blocker summary.
  --next-action TEXT             Short next action.
  --self-test                    Verify parser, validation, and CSV output.
  --help                         Show this help.
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
  if [[ ! -s "$TRACKER_DIR/compatibility.csv" ]]; then
    printf 'Compatibility tracker missing. Run ./script/prepare_alpha_tracker.sh first.\n' >&2
    exit 1
  fi
}

append_compatibility_row() {
  ensure_tracker

  if [[ -z "$TESTER_ID" ]]; then
    printf 'Missing required --tester-id.\n' >&2
    exit 64
  fi

  if ! printf '%s\n' "$CHECK_DATE" | /usr/bin/grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    printf 'Invalid check date: %s. Use YYYY-MM-DD.\n' "$CHECK_DATE" >&2
    exit 64
  fi

  validate_choice "cpu" "$CPU" $'apple_silicon\nintel\nunknown'
  validate_choice "display setup" "$DISPLAY_SETUP" $'built_in\nexternal\nmultiple\nclamshell\nunknown'
  validate_choice "build verify" "$BUILD_VERIFY" $'not_run\npass\nwarn\nfail'
  validate_choice "preview glass" "$PREVIEW_GLASS" $'unknown\nnot_run\nprivate\nfallback\nfail'
  validate_choice "lock screen visible" "$LOCK_SCREEN_VISIBLE" $'yes\nno\nunknown'
  validate_choice "unlock hides overlay" "$UNLOCK_HIDES_OVERLAY" $'yes\nno\nunknown'
  validate_choice "LaunchAgent stable" "$LAUNCHAGENT_STABLE" $'yes\nno\nunknown'
  validate_choice "result" "$RESULT" $'pass\nwarn\nfail'

  validate_safe_text "tester id" "$TESTER_ID"
  validate_safe_text "macOS version" "$MACOS_VERSION"
  validate_safe_text "blocker" "$BLOCKER"
  validate_safe_text "next action" "$NEXT_ACTION"

  {
    csv_escape "$TESTER_ID"; printf ','
    csv_escape "$CHECK_DATE"; printf ','
    csv_escape "$MACOS_VERSION"; printf ','
    csv_escape "$CPU"; printf ','
    csv_escape "$DISPLAY_SETUP"; printf ','
    csv_escape "$BUILD_VERIFY"; printf ','
    csv_escape "$PREVIEW_GLASS"; printf ','
    csv_escape "$LOCK_SCREEN_VISIBLE"; printf ','
    csv_escape "$UNLOCK_HIDES_OVERLAY"; printf ','
    csv_escape "$LAUNCHAGENT_STABLE"; printf ','
    csv_escape "$RESULT"; printf ','
    csv_escape "$BLOCKER"; printf ','
    csv_escape "$NEXT_ACTION"; printf '\n'
  } >>"$TRACKER_DIR/compatibility.csv"

  printf 'Recorded safe compatibility evidence for tester %s.\n' "$TESTER_ID"
  printf 'Tracker: %s\n' "$TRACKER_DIR/compatibility.csv"
}

self_test() {
  local temp_dir output live_env
  live_env="live"
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-record-compatibility.XXXXXX)"
  trap 'rm -rf "$temp_dir"' RETURN

  /bin/mkdir -p "$temp_dir/tracker"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/compatibility.csv" "$temp_dir/tracker/compatibility.csv"

  output="$("$0" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_001 \
    --check-date 2026-06-08 \
    --macos-version 15.5 \
    --cpu apple_silicon \
    --display-setup built_in \
    --build-verify pass \
    --preview-glass private \
    --lock-screen-visible yes \
    --unlock-hides-overlay yes \
    --launchagent-stable yes \
    --result pass \
    --blocker none \
    --next-action 'day 7 follow-up')"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Recorded safe compatibility evidence'
  /usr/bin/tail -1 "$temp_dir/tracker/compatibility.csv" | /usr/bin/grep -q '"tester_001","2026-06-08","15.5","apple_silicon","built_in","pass","private","yes","yes","yes","pass"'

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id 'founder@example.com' >/dev/null 2>&1; then
    printf 'record_alpha_compatibility self-test failed: email-like tester id was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_002 --blocker 'MRR US$10,248.00' >/dev/null 2>&1; then
    printf 'record_alpha_compatibility self-test failed: obvious money amount was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_002 --blocker 'Revenue: 10248.00' >/dev/null 2>&1; then
    printf 'record_alpha_compatibility self-test failed: revenue-labelled money amount was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_003 --blocker "key rk_${live_env}_1234567890abcdef" >/dev/null 2>&1; then
    printf 'record_alpha_compatibility self-test failed: secret-like token was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_004 --blocker 'invoice_pdf was pasted from raw Stripe output' >/dev/null 2>&1; then
    printf 'record_alpha_compatibility self-test failed: raw Stripe field was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_004 --preview-glass animated >/dev/null 2>&1; then
    printf 'record_alpha_compatibility self-test failed: invalid preview glass value was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_XXX >/dev/null 2>&1; then
    printf 'record_alpha_compatibility self-test failed: placeholder tester id was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_005 --macos-version 15.x >/dev/null 2>&1; then
    printf 'record_alpha_compatibility self-test failed: placeholder macOS version was accepted.\n' >&2
    exit 1
  fi

  printf 'Alpha compatibility recorder self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracker-dir) require_arg "$1" "${2:-}"; TRACKER_DIR="$2"; shift 2 ;;
    --tester-id) require_arg "$1" "${2:-}"; TESTER_ID="$2"; shift 2 ;;
    --check-date) require_arg "$1" "${2:-}"; CHECK_DATE="$2"; shift 2 ;;
    --macos-version) require_arg "$1" "${2:-}"; MACOS_VERSION="$2"; shift 2 ;;
    --cpu) require_arg "$1" "${2:-}"; CPU="$2"; shift 2 ;;
    --display-setup) require_arg "$1" "${2:-}"; DISPLAY_SETUP="$2"; shift 2 ;;
    --build-verify) require_arg "$1" "${2:-}"; BUILD_VERIFY="$2"; shift 2 ;;
    --preview-glass) require_arg "$1" "${2:-}"; PREVIEW_GLASS="$2"; shift 2 ;;
    --lock-screen-visible) require_arg "$1" "${2:-}"; LOCK_SCREEN_VISIBLE="$2"; shift 2 ;;
    --unlock-hides-overlay) require_arg "$1" "${2:-}"; UNLOCK_HIDES_OVERLAY="$2"; shift 2 ;;
    --launchagent-stable) require_arg "$1" "${2:-}"; LAUNCHAGENT_STABLE="$2"; shift 2 ;;
    --result) require_arg "$1" "${2:-}"; RESULT="$2"; shift 2 ;;
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

append_compatibility_row
