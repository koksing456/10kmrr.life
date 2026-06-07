#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
SMOKE_DATE="$(/bin/date '+%Y-%m-%d')"
BUILD_VERIFY="not_run"
INSTALL_AGENT="not_run"
DIAGNOSE_AFTER_INSTALL="not_run"
REPAIR_PRESERVES_DATA="not_run"
SUPPORT_REPORT_SAFE="not_run"
UNINSTALL_ALL="not_run"
RESULT="warn"
BLOCKER=""
NEXT_ACTION=""
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 [options]

Appends one safe local-smoke row to the private ignored alpha tracker:
  build/alpha-tracker/local-smoke.csv

This records local release-smoke evidence. It does not run install, repair, or
uninstall commands. Do not include Stripe keys, exact MRR, raw logs, raw Stripe
responses, customer/payment data, contact details, or unsanitized screenshots.

Options:
  --tracker-dir DIR                 Tracker directory. Default: build/alpha-tracker.
  --smoke-date YYYY-MM-DD           Smoke date. Default: today.
  --build-verify VALUE              not_run|pass|warn|fail
  --install-agent VALUE             not_run|pass|warn|fail
  --diagnose-after-install VALUE    not_run|pass|warn|fail
  --repair-preserves-data VALUE     not_run|pass|warn|fail
  --support-report-safe VALUE       not_run|pass|warn|fail
  --uninstall-all VALUE             not_run|pass|warn|fail
  --result VALUE                    pass|warn|fail
  --blocker TEXT                    Short non-sensitive blocker summary.
  --next-action TEXT                Short next action.
  --self-test                       Verify parser, validation, and CSV output.
  --help                            Show this help.
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
  if [[ ! -s "$TRACKER_DIR/local-smoke.csv" ]]; then
    printf 'Local smoke tracker missing. Run ./script/prepare_alpha_tracker.sh first.\n' >&2
    exit 1
  fi
}

append_smoke_row() {
  ensure_tracker

  if ! printf '%s\n' "$SMOKE_DATE" | /usr/bin/grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    printf 'Invalid smoke date: %s. Use YYYY-MM-DD.\n' "$SMOKE_DATE" >&2
    exit 64
  fi

  validate_choice "build verify" "$BUILD_VERIFY" $'not_run\npass\nwarn\nfail'
  validate_choice "install agent" "$INSTALL_AGENT" $'not_run\npass\nwarn\nfail'
  validate_choice "diagnose after install" "$DIAGNOSE_AFTER_INSTALL" $'not_run\npass\nwarn\nfail'
  validate_choice "repair preserves data" "$REPAIR_PRESERVES_DATA" $'not_run\npass\nwarn\nfail'
  validate_choice "support report safe" "$SUPPORT_REPORT_SAFE" $'not_run\npass\nwarn\nfail'
  validate_choice "uninstall all" "$UNINSTALL_ALL" $'not_run\npass\nwarn\nfail'
  validate_choice "result" "$RESULT" $'pass\nwarn\nfail'

  validate_safe_text "blocker" "$BLOCKER"
  validate_safe_text "next action" "$NEXT_ACTION"

  {
    csv_escape "$SMOKE_DATE"; printf ','
    csv_escape "$BUILD_VERIFY"; printf ','
    csv_escape "$INSTALL_AGENT"; printf ','
    csv_escape "$DIAGNOSE_AFTER_INSTALL"; printf ','
    csv_escape "$REPAIR_PRESERVES_DATA"; printf ','
    csv_escape "$SUPPORT_REPORT_SAFE"; printf ','
    csv_escape "$UNINSTALL_ALL"; printf ','
    csv_escape "$RESULT"; printf ','
    csv_escape "$BLOCKER"; printf ','
    csv_escape "$NEXT_ACTION"; printf '\n'
  } >>"$TRACKER_DIR/local-smoke.csv"

  printf 'Recorded safe local smoke evidence for %s.\n' "$SMOKE_DATE"
  printf 'Tracker: %s\n' "$TRACKER_DIR/local-smoke.csv"
}

self_test() {
  local temp_dir output live_env
  live_env="live"
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-record-smoke.XXXXXX)"
  trap 'rm -rf "$temp_dir"' RETURN

  /bin/mkdir -p "$temp_dir/tracker"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/local-smoke.csv" "$temp_dir/tracker/local-smoke.csv"

  output="$("$0" \
    --tracker-dir "$temp_dir/tracker" \
    --smoke-date 2026-06-08 \
    --build-verify pass \
    --install-agent pass \
    --diagnose-after-install pass \
    --repair-preserves-data pass \
    --support-report-safe pass \
    --uninstall-all pass \
    --result pass \
    --next-action 'ready for beta gate')"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Recorded safe local smoke evidence'
  /usr/bin/tail -1 "$temp_dir/tracker/local-smoke.csv" | /usr/bin/grep -q '"2026-06-08","pass","pass","pass","pass","pass","pass","pass"'

  if "$0" --tracker-dir "$temp_dir/tracker" --blocker 'MRR US$10,248.00' >/dev/null 2>&1; then
    printf 'record_alpha_local_smoke self-test failed: obvious money amount was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --blocker 'amount=10248.00' >/dev/null 2>&1; then
    printf 'record_alpha_local_smoke self-test failed: amount-labelled money amount was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --blocker "key rk_${live_env}_1234567890abcdef" >/dev/null 2>&1; then
    printf 'record_alpha_local_smoke self-test failed: secret-like token was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --blocker 'payment intent pi_1234567890abcdef appeared in report' >/dev/null 2>&1; then
    printf 'record_alpha_local_smoke self-test failed: Stripe object id was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --support-report-safe maybe >/dev/null 2>&1; then
    printf 'record_alpha_local_smoke self-test failed: invalid support report value was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --next-action 'record on macOS 15.x' >/dev/null 2>&1; then
    printf 'record_alpha_local_smoke self-test failed: placeholder macOS version was accepted.\n' >&2
    exit 1
  fi

  printf 'Alpha local smoke recorder self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracker-dir) require_arg "$1" "${2:-}"; TRACKER_DIR="$2"; shift 2 ;;
    --smoke-date) require_arg "$1" "${2:-}"; SMOKE_DATE="$2"; shift 2 ;;
    --build-verify) require_arg "$1" "${2:-}"; BUILD_VERIFY="$2"; shift 2 ;;
    --install-agent) require_arg "$1" "${2:-}"; INSTALL_AGENT="$2"; shift 2 ;;
    --diagnose-after-install) require_arg "$1" "${2:-}"; DIAGNOSE_AFTER_INSTALL="$2"; shift 2 ;;
    --repair-preserves-data) require_arg "$1" "${2:-}"; REPAIR_PRESERVES_DATA="$2"; shift 2 ;;
    --support-report-safe) require_arg "$1" "${2:-}"; SUPPORT_REPORT_SAFE="$2"; shift 2 ;;
    --uninstall-all) require_arg "$1" "${2:-}"; UNINSTALL_ALL="$2"; shift 2 ;;
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

append_smoke_row
