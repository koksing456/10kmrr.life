#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
TESTER_ID=""
FOLLOW_UP_DATE="$(/bin/date '+%Y-%m-%d')"
RETAINED_DAY_7="unknown"
OVERALL_PRO_SIGNAL="none"
CUSTOM_DESIGN="0"
POSITION_SIZE_CONTROLS="0"
REFRESH_CACHE_CONTROLS="0"
MULTI_CURRENCY_POLISH="0"
MRR_GOAL_DELTA_MILESTONE="0"
SIGNED_NOTARIZED_INSTALLER="0"
COMPATIBILITY_UPDATES="0"
PREFERRED_PRICING="unknown"
NOTES=""
BLOCKER=""
NEXT_ACTION=""
USES_STRIPE_SUBSCRIPTIONS="unknown"
MACOS_VERSION="unknown"
CPU="unknown"
DISPLAY_SETUP="unknown"
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 --tester-id ID --retained-day-7 VALUE [options]

Records the common Day 7 alpha follow-up packet:
  1. one Pro-interest row
  2. one alpha-users stage snapshot

This is a convenience wrapper around record_alpha_pro_followup.sh and
record_alpha_user.sh. It rejects unsafe values through those scripts before
writing to the private ignored tracker.

Options:
  --tracker-dir DIR                  Tracker directory. Default: build/alpha-tracker.
  --tester-id ID                     Required stable tester id, such as tester_001.
  --follow-up-date YYYY-MM-DD        Follow-up date. Default: today.
  --retained-day-7 VALUE             yes|no|unknown.
  --overall-pro-signal VALUE         none|low|medium|high|unknown.
  --custom-design SCORE              0|1|2|3.
  --position-size-controls SCORE     0|1|2|3.
  --refresh-cache-controls SCORE     0|1|2|3.
  --multi-currency-polish SCORE      0|1|2|3.
  --mrr-goal-delta-milestone SCORE   0|1|2|3.
  --signed-notarized-installer SCORE 0|1|2|3.
  --compatibility-updates SCORE      0|1|2|3.
  --preferred-pricing TEXT           Short sanitized pricing model, not private revenue.
  --notes TEXT                       Short non-sensitive notes.
  --blocker TEXT                     Short non-sensitive blocker summary.
  --next-action TEXT                 Short non-sensitive next action. Default is derived.
  --uses-stripe-subscriptions VALUE  yes|no|unknown.
  --macos-version VALUE              Non-sensitive version summary, for example 15.5.
  --cpu VALUE                        apple_silicon|intel|unknown.
  --display-setup VALUE              built_in|external|multiple|unknown.
  --self-test                        Verify wrapper behavior in a temporary tracker.
  --help                             Show this help.
EOF
}

require_arg() {
  local option="$1"
  if [[ $# -lt 2 || "${2:-}" == --* ]]; then
    printf 'Missing value for %s.\n' "$option" >&2
    exit 64
  fi
}

ensure_tracker() {
  if [[ ! -s "$TRACKER_DIR/pro-interest.csv" || ! -s "$TRACKER_DIR/alpha-users.csv" ]]; then
    printf 'Alpha tracker missing. Run ./script/prepare_alpha_tracker.sh first.\n' >&2
    exit 1
  fi
}

derived_stage() {
  case "$RETAINED_DAY_7" in
    yes) printf 'retained_day_7' ;;
    no) printf 'closed_lost' ;;
    unknown) printf 'saw_mrr' ;;
    *) printf 'saw_mrr' ;;
  esac
}

derived_next_action() {
  if [[ -n "$NEXT_ACTION" ]]; then
    printf '%s' "$NEXT_ACTION"
    return
  fi

  case "$RETAINED_DAY_7:$OVERALL_PRO_SIGNAL" in
    yes:high|yes:medium) printf 'ask for Pro willingness and testimonial approval' ;;
    yes:*) printf 'keep warm and invite next tester' ;;
    no:*) printf 'review blocker before next invite' ;;
    *) printf 'clarify retention and Pro signal' ;;
  esac
}

copy_tracker_for_preflight() {
  local target_dir="$1"

  /bin/mkdir -p "$target_dir"
  /bin/cp "$TRACKER_DIR/pro-interest.csv" "$target_dir/pro-interest.csv"
  /bin/cp "$TRACKER_DIR/alpha-users.csv" "$target_dir/alpha-users.csv"
}

record_pro_followup() {
  local tracker_dir="$1"

  "$ROOT_DIR/script/record_alpha_pro_followup.sh" \
    --tracker-dir "$tracker_dir" \
    --tester-id "$TESTER_ID" \
    --follow-up-date "$FOLLOW_UP_DATE" \
    --retained-day-7 "$RETAINED_DAY_7" \
    --custom-design "$CUSTOM_DESIGN" \
    --position-size-controls "$POSITION_SIZE_CONTROLS" \
    --refresh-cache-controls "$REFRESH_CACHE_CONTROLS" \
    --multi-currency-polish "$MULTI_CURRENCY_POLISH" \
    --mrr-goal-delta-milestone "$MRR_GOAL_DELTA_MILESTONE" \
    --signed-notarized-installer "$SIGNED_NOTARIZED_INSTALLER" \
    --compatibility-updates "$COMPATIBILITY_UPDATES" \
    --preferred-pricing "$PREFERRED_PRICING" \
    --overall-pro-signal "$OVERALL_PRO_SIGNAL" \
    --notes "$NOTES"
}

record_user_snapshot() {
  local tracker_dir="$1"
  local next_action stage

  next_action="$(derived_next_action)"
  stage="$(derived_stage)"

  "$ROOT_DIR/script/record_alpha_user.sh" \
    --tracker-dir "$tracker_dir" \
    --tester-id "$TESTER_ID" \
    --uses-stripe-subscriptions "$USES_STRIPE_SUBSCRIPTIONS" \
    --macos-version "$MACOS_VERSION" \
    --cpu "$CPU" \
    --display-setup "$DISPLAY_SETUP" \
    --approved yes \
    --current-stage "$stage" \
    --install-status pass \
    --key-setup-status pass \
    --first-mrr-seen yes \
    --retained-day-7 "$RETAINED_DAY_7" \
    --pro-interest "$OVERALL_PRO_SIGNAL" \
    --blocker "$BLOCKER" \
    --next-action "$next_action"
}

preflight_records() {
  local temp_dir result=0
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-alpha-day7-preflight.XXXXXX)"

  {
    copy_tracker_for_preflight "$temp_dir/tracker" &&
      record_pro_followup "$temp_dir/tracker" >/dev/null &&
      record_user_snapshot "$temp_dir/tracker" >/dev/null
  } || result=$?

  /bin/rm -rf "$temp_dir"
  return "$result"
}

append_day7_records() {
  local next_action
  ensure_tracker

  if [[ -z "$TESTER_ID" ]]; then
    printf 'Missing required --tester-id.\n' >&2
    exit 64
  fi

  preflight_records
  record_pro_followup "$TRACKER_DIR"
  record_user_snapshot "$TRACKER_DIR"

  next_action="$(derived_next_action)"
  printf '\nRecorded Day 7 alpha follow-up packet for tester %s.\n' "$TESTER_ID"
  printf 'Next: %s\n' "$next_action"
  printf 'Weekly rollup: ./script/alpha.sh weekly\n'
}

self_test() {
  local temp_dir output live_env result=0
  live_env="live"
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-alpha-day7.XXXXXX)"

  /bin/mkdir -p "$temp_dir/tracker"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/pro-interest.csv" "$temp_dir/tracker/pro-interest.csv"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/alpha-users.csv" "$temp_dir/tracker/alpha-users.csv"

  output="$("$0" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_001 \
    --follow-up-date 2026-06-15 \
    --retained-day-7 yes \
    --overall-pro-signal medium \
    --signed-notarized-installer 3 \
    --compatibility-updates 2 \
    --preferred-pricing 'small subscription' \
    --notes 'kept it on for day 7' \
    --macos-version 15.5 \
    --cpu apple_silicon \
    --display-setup built_in)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Recorded Day 7 alpha follow-up packet'
  printf '%s\n' "$output" | /usr/bin/grep -q './script/alpha.sh weekly'
  /usr/bin/tail -1 "$temp_dir/tracker/pro-interest.csv" | /usr/bin/grep -q '"tester_001","2026-06-15","yes"'
  /usr/bin/tail -1 "$temp_dir/tracker/alpha-users.csv" | /usr/bin/grep -q '"tester_001","unknown","15.5","apple_silicon","built_in","yes","retained_day_7","pass","pass","yes","yes","medium"'

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id 'founder@example.com' --retained-day-7 yes >/dev/null 2>&1; then
    printf 'record_alpha_day7 self-test failed: email-like tester id was accepted.\n' >&2
    result=1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_002 --retained-day-7 yes --notes 'MRR US$10,248.00' >/dev/null 2>&1; then
    printf 'record_alpha_day7 self-test failed: obvious money amount was accepted.\n' >&2
    result=1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_003 --retained-day-7 yes --notes "key rk_${live_env}_1234567890abcdef" >/dev/null 2>&1; then
    printf 'record_alpha_day7 self-test failed: secret-like token was accepted.\n' >&2
    result=1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_004 --retained-day-7 maybe >/dev/null 2>&1; then
    printf 'record_alpha_day7 self-test failed: invalid retained value was accepted.\n' >&2
    result=1
  fi

  /bin/rm -rf "$temp_dir"
  if [[ "$result" -ne 0 ]]; then
    exit "$result"
  fi

  printf 'Alpha Day 7 follow-up wrapper self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracker-dir) require_arg "$1" "${2:-}"; TRACKER_DIR="$2"; shift 2 ;;
    --tester-id) require_arg "$1" "${2:-}"; TESTER_ID="$2"; shift 2 ;;
    --follow-up-date) require_arg "$1" "${2:-}"; FOLLOW_UP_DATE="$2"; shift 2 ;;
    --retained-day-7) require_arg "$1" "${2:-}"; RETAINED_DAY_7="$2"; shift 2 ;;
    --overall-pro-signal) require_arg "$1" "${2:-}"; OVERALL_PRO_SIGNAL="$2"; shift 2 ;;
    --custom-design) require_arg "$1" "${2:-}"; CUSTOM_DESIGN="$2"; shift 2 ;;
    --position-size-controls) require_arg "$1" "${2:-}"; POSITION_SIZE_CONTROLS="$2"; shift 2 ;;
    --refresh-cache-controls) require_arg "$1" "${2:-}"; REFRESH_CACHE_CONTROLS="$2"; shift 2 ;;
    --multi-currency-polish) require_arg "$1" "${2:-}"; MULTI_CURRENCY_POLISH="$2"; shift 2 ;;
    --mrr-goal-delta-milestone) require_arg "$1" "${2:-}"; MRR_GOAL_DELTA_MILESTONE="$2"; shift 2 ;;
    --signed-notarized-installer) require_arg "$1" "${2:-}"; SIGNED_NOTARIZED_INSTALLER="$2"; shift 2 ;;
    --compatibility-updates) require_arg "$1" "${2:-}"; COMPATIBILITY_UPDATES="$2"; shift 2 ;;
    --preferred-pricing) require_arg "$1" "${2:-}"; PREFERRED_PRICING="$2"; shift 2 ;;
    --notes) require_arg "$1" "${2:-}"; NOTES="$2"; shift 2 ;;
    --blocker) require_arg "$1" "${2:-}"; BLOCKER="$2"; shift 2 ;;
    --next-action) require_arg "$1" "${2:-}"; NEXT_ACTION="$2"; shift 2 ;;
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

append_day7_records
