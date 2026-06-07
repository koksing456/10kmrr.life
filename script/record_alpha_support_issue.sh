#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
TESTER_ID=""
EVIDENCE_DATE="$(/bin/date '+%Y-%m-%d')"
ISSUE_TYPE="unknown"
RESULT="warn"
MACOS_VERSION="unknown"
CPU="unknown"
DISPLAY_SETUP="unknown"
BLOCKER=""
NEXT_ACTION="send support report summary"
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 --tester-id ID --issue-type TYPE [options]

Records a safe alpha support issue packet for a tester who is blocked or
warning before the common success path. It writes an install-funnel row and,
for Lock Screen/private API/LaunchAgent issues, also writes a compatibility row.

This is a convenience wrapper around record_alpha_install.sh and
record_alpha_compatibility.sh. It rejects unsafe text before writing to the
private ignored tracker.

Options:
  --tracker-dir DIR       Tracker directory. Default: build/alpha-tracker.
  --tester-id ID          Required stable tester id, such as tester_001.
  --evidence-date DATE    Date for written rows. Default: today.
  --issue-type TYPE       build|key|stripe_permission|preview|install|launchagent|lock_screen|private_glass|unknown.
  --result VALUE          warn|fail. Default: warn.
  --macos-version VALUE   Non-sensitive version summary, for example 15.5.
  --cpu VALUE             apple_silicon|intel|unknown.
  --display-setup VALUE   built_in|external|multiple|clamshell|unknown.
  --blocker TEXT          Short non-sensitive blocker summary.
  --next-action TEXT      Short non-sensitive next action.
  --self-test             Verify wrapper behavior in a temporary tracker.
  --help                  Show this help.
EOF
}

require_arg() {
  local option="$1"
  if [[ $# -lt 2 || "${2:-}" == --* ]]; then
    printf 'Missing value for %s.\n' "$option" >&2
    exit 64
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

  if printf '%s\n' "$value" | /usr/bin/grep -Eiq '(raw[ _-]?log|raw[ _-]?stripe|screenshot|screen shot|dashboard screenshot|customer name|invoice|payment data)'; then
    printf 'Unsafe %s: contains raw logs, screenshots, or customer/payment-data wording. Use a pass/warn/fail summary instead.\n' "$label" >&2
    exit 1
  fi
}

ensure_tracker() {
  if [[ ! -s "$TRACKER_DIR/install-funnel.csv" || ! -s "$TRACKER_DIR/compatibility.csv" ]]; then
    printf 'Alpha tracker missing. Run ./script/prepare_alpha_tracker.sh first.\n' >&2
    exit 1
  fi
}

install_stage() {
  case "$ISSUE_TYPE" in
    build) printf 'built' ;;
    key|stripe_permission) printf 'configured_key' ;;
    preview|private_glass) printf 'previewed' ;;
    install|launchagent|lock_screen) printf 'installed' ;;
    *) printf 'approved' ;;
  esac
}

build_verify_value() {
  case "$ISSUE_TYPE" in
    build) printf '%s' "$RESULT" ;;
    *) printf 'pass' ;;
  esac
}

configured_key_value() {
  case "$ISSUE_TYPE" in
    build|key|stripe_permission) printf 'no' ;;
    *) printf 'unknown' ;;
  esac
}

previewed_value() {
  case "$ISSUE_TYPE" in
    preview|private_glass) printf 'no' ;;
    install|launchagent|lock_screen) printf 'yes' ;;
    *) printf 'no' ;;
  esac
}

installed_value() {
  case "$ISSUE_TYPE" in
    launchagent|lock_screen) printf 'yes' ;;
    install) printf 'no' ;;
    *) printf 'no' ;;
  esac
}

saw_mrr_value() {
  case "$ISSUE_TYPE" in
    lock_screen|launchagent) printf 'unknown' ;;
    *) printf 'no' ;;
  esac
}

diagnose_summary() {
  printf '%s %s issue' "$(printf '%s' "$RESULT" | /usr/bin/tr '[:lower:]' '[:upper:]')" "$ISSUE_TYPE"
}

needs_compatibility_row() {
  case "$ISSUE_TYPE" in
    launchagent|lock_screen|private_glass) return 0 ;;
    *) return 1 ;;
  esac
}

preview_glass_value() {
  case "$ISSUE_TYPE" in
    private_glass) printf 'fail' ;;
    lock_screen|launchagent) printf 'unknown' ;;
    *) printf 'not_run' ;;
  esac
}

lock_screen_visible_value() {
  case "$ISSUE_TYPE" in
    lock_screen) printf 'no' ;;
    *) printf 'unknown' ;;
  esac
}

launchagent_stable_value() {
  case "$ISSUE_TYPE" in
    launchagent) printf 'no' ;;
    *) printf 'unknown' ;;
  esac
}

compatibility_result() {
  printf '%s' "$RESULT"
}

copy_tracker_for_preflight() {
  local target_dir="$1"

  /bin/mkdir -p "$target_dir"
  /bin/cp "$TRACKER_DIR/install-funnel.csv" "$target_dir/install-funnel.csv"
  /bin/cp "$TRACKER_DIR/compatibility.csv" "$target_dir/compatibility.csv"
}

record_install_issue() {
  local tracker_dir="$1"

  "$ROOT_DIR/script/record_alpha_install.sh" \
    --tracker-dir "$tracker_dir" \
    --tester-id "$TESTER_ID" \
    --attempt-date "$EVIDENCE_DATE" \
    --stage "$(install_stage)" \
    --build-verify "$(build_verify_value)" \
    --configured-key "$(configured_key_value)" \
    --previewed "$(previewed_value)" \
    --installed "$(installed_value)" \
    --saw-mrr "$(saw_mrr_value)" \
    --diagnose-summary "$(diagnose_summary)" \
    --blocker "$BLOCKER" \
    --next-action "$NEXT_ACTION"
}

record_compatibility_issue() {
  local tracker_dir="$1"

  "$ROOT_DIR/script/record_alpha_compatibility.sh" \
    --tracker-dir "$tracker_dir" \
    --tester-id "$TESTER_ID" \
    --check-date "$EVIDENCE_DATE" \
    --macos-version "$MACOS_VERSION" \
    --cpu "$CPU" \
    --display-setup "$DISPLAY_SETUP" \
    --build-verify "$(build_verify_value)" \
    --preview-glass "$(preview_glass_value)" \
    --lock-screen-visible "$(lock_screen_visible_value)" \
    --unlock-hides-overlay unknown \
    --launchagent-stable "$(launchagent_stable_value)" \
    --result "$(compatibility_result)" \
    --blocker "$BLOCKER" \
    --next-action "$NEXT_ACTION"
}

preflight_records() {
  local temp_dir result=0
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-alpha-support-preflight.XXXXXX)"

  {
    copy_tracker_for_preflight "$temp_dir/tracker" &&
      record_install_issue "$temp_dir/tracker" >/dev/null
    if needs_compatibility_row; then
      record_compatibility_issue "$temp_dir/tracker" >/dev/null
    fi
  } || result=$?

  /bin/rm -rf "$temp_dir"
  return "$result"
}

append_support_issue() {
  ensure_tracker

  if [[ -z "$TESTER_ID" ]]; then
    printf 'Missing required --tester-id.\n' >&2
    exit 64
  fi

  validate_choice "issue type" "$ISSUE_TYPE" $'build\nkey\nstripe_permission\npreview\ninstall\nlaunchagent\nlock_screen\nprivate_glass\nunknown'
  validate_choice "result" "$RESULT" $'warn\nfail'
  validate_choice "cpu" "$CPU" $'apple_silicon\nintel\nunknown'
  validate_choice "display setup" "$DISPLAY_SETUP" $'built_in\nexternal\nmultiple\nclamshell\nunknown'
  validate_safe_text "tester id" "$TESTER_ID"
  validate_safe_text "macOS version" "$MACOS_VERSION"
  validate_safe_text "blocker" "$BLOCKER"
  validate_safe_text "next action" "$NEXT_ACTION"

  if ! printf '%s\n' "$EVIDENCE_DATE" | /usr/bin/grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    printf 'Invalid evidence date: %s. Use YYYY-MM-DD.\n' "$EVIDENCE_DATE" >&2
    exit 64
  fi

  preflight_records
  record_install_issue "$TRACKER_DIR"
  if needs_compatibility_row; then
    record_compatibility_issue "$TRACKER_DIR"
  fi

  printf '\nRecorded safe alpha support issue packet for tester %s.\n' "$TESTER_ID"
  printf 'Issue type: %s\n' "$ISSUE_TYPE"
  printf 'Next: %s\n' "$NEXT_ACTION"
}

self_test() {
  local temp_dir output live_env result=0
  live_env="live"
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-alpha-support.XXXXXX)"

  /bin/mkdir -p "$temp_dir/tracker"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/install-funnel.csv" "$temp_dir/tracker/install-funnel.csv"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/compatibility.csv" "$temp_dir/tracker/compatibility.csv"

  output="$("$0" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_001 \
    --evidence-date 2026-06-08 \
    --issue-type lock_screen \
    --result fail \
    --macos-version 15.5 \
    --cpu apple_silicon \
    --display-setup built_in \
    --blocker 'Lock Screen panel did not appear' \
    --next-action 'repair then retry diagnose')"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Recorded safe alpha support issue packet'
  /usr/bin/tail -1 "$temp_dir/tracker/install-funnel.csv" | /usr/bin/grep -q '"tester_001","2026-06-08","installed","pass","unknown","yes","yes","unknown","FAIL lock_screen issue"'
  /usr/bin/tail -1 "$temp_dir/tracker/compatibility.csv" | /usr/bin/grep -q '"tester_001","2026-06-08","15.5","apple_silicon","built_in","pass","unknown","no","unknown","unknown","fail"'

  output="$("$0" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_002 \
    --evidence-date 2026-06-08 \
    --issue-type key \
    --result warn \
    --blocker 'restricted key not configured yet')"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Recorded safe alpha support issue packet'
  /usr/bin/tail -1 "$temp_dir/tracker/install-funnel.csv" | /usr/bin/grep -q '"tester_002","2026-06-08","configured_key","pass","no","no","no","no","WARN key issue"'

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id 'founder@example.com' --issue-type key >/dev/null 2>&1; then
    printf 'record_alpha_support_issue self-test failed: email-like tester id was accepted.\n' >&2
    result=1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_003 --issue-type key --blocker "key rk_${live_env}_1234567890abcdef" >/dev/null 2>&1; then
    printf 'record_alpha_support_issue self-test failed: secret-like token was accepted.\n' >&2
    result=1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_004 --issue-type key --blocker 'MRR US$10,248.00' >/dev/null 2>&1; then
    printf 'record_alpha_support_issue self-test failed: obvious money amount was accepted.\n' >&2
    result=1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_005 --issue-type key --blocker 'raw log had stack trace' >/dev/null 2>&1; then
    printf 'record_alpha_support_issue self-test failed: raw log wording was accepted.\n' >&2
    result=1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_006 --issue-type unknown --result pass >/dev/null 2>&1; then
    printf 'record_alpha_support_issue self-test failed: invalid result was accepted.\n' >&2
    result=1
  fi

  /bin/rm -rf "$temp_dir"
  if [[ "$result" -ne 0 ]]; then
    exit "$result"
  fi

  printf 'Alpha support issue recorder self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracker-dir) require_arg "$1" "${2:-}"; TRACKER_DIR="$2"; shift 2 ;;
    --tester-id) require_arg "$1" "${2:-}"; TESTER_ID="$2"; shift 2 ;;
    --evidence-date) require_arg "$1" "${2:-}"; EVIDENCE_DATE="$2"; shift 2 ;;
    --issue-type) require_arg "$1" "${2:-}"; ISSUE_TYPE="$2"; shift 2 ;;
    --result) require_arg "$1" "${2:-}"; RESULT="$2"; shift 2 ;;
    --macos-version) require_arg "$1" "${2:-}"; MACOS_VERSION="$2"; shift 2 ;;
    --cpu) require_arg "$1" "${2:-}"; CPU="$2"; shift 2 ;;
    --display-setup) require_arg "$1" "${2:-}"; DISPLAY_SETUP="$2"; shift 2 ;;
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

append_support_issue
