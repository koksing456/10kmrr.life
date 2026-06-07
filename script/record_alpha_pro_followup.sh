#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
FOLLOW_UP_DATE="$(/bin/date '+%Y-%m-%d')"
TESTER_ID=""
RETAINED_DAY_7="unknown"
CUSTOM_DESIGN="0"
POSITION_SIZE_CONTROLS="0"
REFRESH_CACHE_CONTROLS="0"
MULTI_CURRENCY_POLISH="0"
MRR_GOAL_DELTA_MILESTONE="0"
SIGNED_NOTARIZED_INSTALLER="0"
COMPATIBILITY_UPDATES="0"
PREFERRED_PRICING="unknown"
OVERALL_PRO_SIGNAL="none"
NOTES=""
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 --tester-id ID [options]

Appends one safe Day 7 / Pro-interest row to the private ignored alpha tracker:
  build/alpha-tracker/pro-interest.csv

Scores must be 0-3. Notes must stay non-sensitive.

Options:
  --tracker-dir DIR                  Tracker directory. Default: build/alpha-tracker.
  --tester-id ID                     Required stable tester id.
  --follow-up-date YYYY-MM-DD        Follow-up date. Default: today.
  --retained-day-7 VALUE             yes|no|unknown
  --custom-design SCORE              0|1|2|3
  --position-size-controls SCORE     0|1|2|3
  --refresh-cache-controls SCORE     0|1|2|3
  --multi-currency-polish SCORE      0|1|2|3
  --mrr-goal-delta-milestone SCORE   0|1|2|3
  --signed-notarized-installer SCORE 0|1|2|3
  --compatibility-updates SCORE      0|1|2|3
  --preferred-pricing TEXT           Short sanitized pricing model, not exact private revenue.
  --overall-pro-signal VALUE         none|low|medium|high|unknown
  --notes TEXT                       Short non-sensitive notes.
  --self-test                        Verify parser, validation, and CSV output.
  --help                             Show this help.
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

  if printf '%s\n' "$value" | /usr/bin/grep -Eq '([A-Z]{2,4}\$[0-9][0-9,]*(\.[0-9]{2})?|[A-Z]{3}[[:space:]]+[0-9][0-9,]*(\.[0-9]{2})?)'; then
    printf 'Unsafe %s: contains obvious money amount.\n' "$label" >&2
    exit 1
  fi

  if printf '%s\n' "$value" | /usr/bin/grep -Eq '[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+'; then
    printf 'Unsafe %s: contains email-like contact data.\n' "$label" >&2
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
  if [[ ! -s "$TRACKER_DIR/pro-interest.csv" ]]; then
    printf 'Pro-interest tracker missing. Run ./script/prepare_alpha_tracker.sh first.\n' >&2
    exit 1
  fi
}

validate_score() {
  validate_choice "$1" "$2" $'0\n1\n2\n3'
}

append_followup_row() {
  ensure_tracker

  if [[ -z "$TESTER_ID" ]]; then
    printf 'Missing required --tester-id.\n' >&2
    exit 64
  fi

  if ! printf '%s\n' "$FOLLOW_UP_DATE" | /usr/bin/grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
    printf 'Invalid follow-up date: %s. Use YYYY-MM-DD.\n' "$FOLLOW_UP_DATE" >&2
    exit 64
  fi

  validate_choice "retained day 7" "$RETAINED_DAY_7" $'yes\nno\nunknown'
  validate_choice "overall pro signal" "$OVERALL_PRO_SIGNAL" $'none\nlow\nmedium\nhigh\nunknown'
  validate_score "custom design" "$CUSTOM_DESIGN"
  validate_score "position size controls" "$POSITION_SIZE_CONTROLS"
  validate_score "refresh cache controls" "$REFRESH_CACHE_CONTROLS"
  validate_score "multi currency polish" "$MULTI_CURRENCY_POLISH"
  validate_score "MRR goal delta milestone" "$MRR_GOAL_DELTA_MILESTONE"
  validate_score "signed notarized installer" "$SIGNED_NOTARIZED_INSTALLER"
  validate_score "compatibility updates" "$COMPATIBILITY_UPDATES"

  validate_safe_text "tester id" "$TESTER_ID"
  validate_safe_text "preferred pricing" "$PREFERRED_PRICING"
  validate_safe_text "notes" "$NOTES"

  {
    csv_escape "$TESTER_ID"; printf ','
    csv_escape "$FOLLOW_UP_DATE"; printf ','
    csv_escape "$RETAINED_DAY_7"; printf ','
    csv_escape "$CUSTOM_DESIGN"; printf ','
    csv_escape "$POSITION_SIZE_CONTROLS"; printf ','
    csv_escape "$REFRESH_CACHE_CONTROLS"; printf ','
    csv_escape "$MULTI_CURRENCY_POLISH"; printf ','
    csv_escape "$MRR_GOAL_DELTA_MILESTONE"; printf ','
    csv_escape "$SIGNED_NOTARIZED_INSTALLER"; printf ','
    csv_escape "$COMPATIBILITY_UPDATES"; printf ','
    csv_escape "$PREFERRED_PRICING"; printf ','
    csv_escape "$OVERALL_PRO_SIGNAL"; printf ','
    csv_escape "$NOTES"; printf '\n'
  } >>"$TRACKER_DIR/pro-interest.csv"

  printf 'Recorded safe Pro follow-up for tester %s.\n' "$TESTER_ID"
  printf 'Tracker: %s\n' "$TRACKER_DIR/pro-interest.csv"
}

self_test() {
  local temp_dir output live_env
  live_env="live"
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-record-pro.XXXXXX)"
  trap 'rm -rf "$temp_dir"' RETURN

  /bin/mkdir -p "$temp_dir/tracker"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/pro-interest.csv" "$temp_dir/tracker/pro-interest.csv"

  output="$("$0" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_001 \
    --follow-up-date 2026-06-15 \
    --retained-day-7 yes \
    --custom-design 2 \
    --position-size-controls 1 \
    --refresh-cache-controls 2 \
    --multi-currency-polish 0 \
    --mrr-goal-delta-milestone 1 \
    --signed-notarized-installer 3 \
    --compatibility-updates 2 \
    --preferred-pricing 'one-time or small subscription' \
    --overall-pro-signal medium \
    --notes 'kept it on for day 7')"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Recorded safe Pro follow-up'
  /usr/bin/tail -1 "$temp_dir/tracker/pro-interest.csv" | /usr/bin/grep -q '"tester_001","2026-06-15","yes","2","1","2"'

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_002 --custom-design 4 >/dev/null 2>&1; then
    printf 'record_alpha_pro_followup self-test failed: invalid score was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_003 --notes 'MRR US$10,248.00' >/dev/null 2>&1; then
    printf 'record_alpha_pro_followup self-test failed: obvious money amount was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_004 --notes "key rk_${live_env}_1234567890abcdef" >/dev/null 2>&1; then
    printf 'record_alpha_pro_followup self-test failed: secret-like token was accepted.\n' >&2
    exit 1
  fi

  printf 'Alpha Pro follow-up recorder self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracker-dir) require_arg "$1" "${2:-}"; TRACKER_DIR="$2"; shift 2 ;;
    --tester-id) require_arg "$1" "${2:-}"; TESTER_ID="$2"; shift 2 ;;
    --follow-up-date) require_arg "$1" "${2:-}"; FOLLOW_UP_DATE="$2"; shift 2 ;;
    --retained-day-7) require_arg "$1" "${2:-}"; RETAINED_DAY_7="$2"; shift 2 ;;
    --custom-design) require_arg "$1" "${2:-}"; CUSTOM_DESIGN="$2"; shift 2 ;;
    --position-size-controls) require_arg "$1" "${2:-}"; POSITION_SIZE_CONTROLS="$2"; shift 2 ;;
    --refresh-cache-controls) require_arg "$1" "${2:-}"; REFRESH_CACHE_CONTROLS="$2"; shift 2 ;;
    --multi-currency-polish) require_arg "$1" "${2:-}"; MULTI_CURRENCY_POLISH="$2"; shift 2 ;;
    --mrr-goal-delta-milestone) require_arg "$1" "${2:-}"; MRR_GOAL_DELTA_MILESTONE="$2"; shift 2 ;;
    --signed-notarized-installer) require_arg "$1" "${2:-}"; SIGNED_NOTARIZED_INSTALLER="$2"; shift 2 ;;
    --compatibility-updates) require_arg "$1" "${2:-}"; COMPATIBILITY_UPDATES="$2"; shift 2 ;;
    --preferred-pricing) require_arg "$1" "${2:-}"; PREFERRED_PRICING="$2"; shift 2 ;;
    --overall-pro-signal) require_arg "$1" "${2:-}"; OVERALL_PRO_SIGNAL="$2"; shift 2 ;;
    --notes) require_arg "$1" "${2:-}"; NOTES="$2"; shift 2 ;;
    --self-test) SELF_TEST=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
done

if [[ "$SELF_TEST" == "true" ]]; then
  self_test
  exit 0
fi

append_followup_row
