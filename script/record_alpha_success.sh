#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
TESTER_ID=""
EVIDENCE_DATE="$(/bin/date '+%Y-%m-%d')"
MACOS_VERSION="unknown"
CPU="apple_silicon"
DISPLAY_SETUP="built_in"
PREVIEW_GLASS="private"
DIAGNOSE_SUMMARY="PASS summary only"
NEXT_ACTION="day 7 follow-up"
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 --tester-id ID [options]

Records the common successful alpha evidence packet for one tester:
  1. install funnel reached saw_mrr
  2. Lock Screen compatibility passed

This is a convenience wrapper around record_alpha_install.sh and
record_alpha_compatibility.sh. It rejects unsafe values through those scripts
before writing to the private ignored tracker.

Options:
  --tracker-dir DIR          Tracker directory. Default: build/alpha-tracker.
  --tester-id ID             Required stable tester id, such as tester_001.
  --evidence-date YYYY-MM-DD Date for both rows. Default: today.
  --macos-version VALUE      Non-sensitive version summary, for example 15.5.
  --cpu VALUE                apple_silicon|intel|unknown. Default: apple_silicon.
  --display-setup VALUE      built_in|external|multiple|clamshell|unknown.
  --preview-glass VALUE      private|fallback. Default: private.
  --diagnose-summary TEXT    Short pass/warn/fail summary, no raw logs.
  --next-action TEXT         Short next action. Default: day 7 follow-up.
  --self-test                Verify wrapper behavior in a temporary tracker.
  --help                     Show this help.
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
  if [[ ! -s "$TRACKER_DIR/install-funnel.csv" || ! -s "$TRACKER_DIR/compatibility.csv" ]]; then
    printf 'Alpha tracker missing. Run ./script/prepare_alpha_tracker.sh first.\n' >&2
    exit 1
  fi
}

copy_tracker_for_preflight() {
  local target_dir="$1"

  /bin/mkdir -p "$target_dir"
  /bin/cp "$TRACKER_DIR/install-funnel.csv" "$target_dir/install-funnel.csv"
  /bin/cp "$TRACKER_DIR/compatibility.csv" "$target_dir/compatibility.csv"
}

record_install() {
  local tracker_dir="$1"

  "$ROOT_DIR/script/record_alpha_install.sh" \
    --tracker-dir "$tracker_dir" \
    --tester-id "$TESTER_ID" \
    --attempt-date "$EVIDENCE_DATE" \
    --stage saw_mrr \
    --build-verify pass \
    --configured-key yes \
    --previewed yes \
    --installed yes \
    --saw-mrr yes \
    --diagnose-summary "$DIAGNOSE_SUMMARY" \
    --next-action "$NEXT_ACTION"
}

record_compatibility() {
  local tracker_dir="$1"

  "$ROOT_DIR/script/record_alpha_compatibility.sh" \
    --tracker-dir "$tracker_dir" \
    --tester-id "$TESTER_ID" \
    --check-date "$EVIDENCE_DATE" \
    --macos-version "$MACOS_VERSION" \
    --cpu "$CPU" \
    --display-setup "$DISPLAY_SETUP" \
    --build-verify pass \
    --preview-glass "$PREVIEW_GLASS" \
    --lock-screen-visible yes \
    --unlock-hides-overlay yes \
    --launchagent-stable yes \
    --result pass \
    --next-action "$NEXT_ACTION"
}

preflight_records() {
  local temp_dir result=0
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-alpha-success-preflight.XXXXXX)"

  {
    copy_tracker_for_preflight "$temp_dir/tracker" &&
      record_install "$temp_dir/tracker" >/dev/null &&
      record_compatibility "$temp_dir/tracker" >/dev/null
  } || result=$?

  /bin/rm -rf "$temp_dir"
  return "$result"
}

append_success_records() {
  ensure_tracker

  if [[ -z "$TESTER_ID" ]]; then
    printf 'Missing required --tester-id.\n' >&2
    exit 64
  fi

  preflight_records
  record_install "$TRACKER_DIR"
  record_compatibility "$TRACKER_DIR"

  printf '\nRecorded successful alpha evidence packet for tester %s.\n' "$TESTER_ID"
  printf 'Next: follow up on day 7, then record retention and Pro signal with ./script/alpha.sh day7.\n'
}

self_test() {
  local temp_dir output live_env result=0
  live_env="live"
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-alpha-success.XXXXXX)"

  /bin/mkdir -p "$temp_dir/tracker"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/install-funnel.csv" "$temp_dir/tracker/install-funnel.csv"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/compatibility.csv" "$temp_dir/tracker/compatibility.csv"

  output="$("$0" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_001 \
    --evidence-date 2026-06-08 \
    --macos-version 15.5 \
    --cpu apple_silicon \
    --display-setup built_in \
    --preview-glass private)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Recorded successful alpha evidence packet'
  printf '%s\n' "$output" | /usr/bin/grep -q './script/alpha.sh day7'
  /usr/bin/tail -1 "$temp_dir/tracker/install-funnel.csv" | /usr/bin/grep -q '"tester_001","2026-06-08","saw_mrr","pass","yes","yes","yes","yes"'
  /usr/bin/tail -1 "$temp_dir/tracker/compatibility.csv" | /usr/bin/grep -q '"tester_001","2026-06-08","15.5","apple_silicon","built_in","pass","private","yes","yes","yes","pass"'

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id 'founder@example.com' >/dev/null 2>&1; then
    printf 'record_alpha_success self-test failed: email-like tester id was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_002 --diagnose-summary 'MRR US$10,248.00' >/dev/null 2>&1; then
    printf 'record_alpha_success self-test failed: obvious money amount was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_003 --diagnose-summary "key rk_${live_env}_1234567890abcdef" >/dev/null 2>&1; then
    printf 'record_alpha_success self-test failed: secret-like token was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --tester-id tester_004 --preview-glass animated >/dev/null 2>&1; then
    printf 'record_alpha_success self-test failed: invalid preview glass value was accepted.\n' >&2
    result=1
  fi

  /bin/rm -rf "$temp_dir"
  if [[ "$result" -ne 0 ]]; then
    exit "$result"
  fi

  printf 'Alpha success evidence wrapper self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracker-dir) require_arg "$1" "${2:-}"; TRACKER_DIR="$2"; shift 2 ;;
    --tester-id) require_arg "$1" "${2:-}"; TESTER_ID="$2"; shift 2 ;;
    --evidence-date) require_arg "$1" "${2:-}"; EVIDENCE_DATE="$2"; shift 2 ;;
    --macos-version) require_arg "$1" "${2:-}"; MACOS_VERSION="$2"; shift 2 ;;
    --cpu) require_arg "$1" "${2:-}"; CPU="$2"; shift 2 ;;
    --display-setup) require_arg "$1" "${2:-}"; DISPLAY_SETUP="$2"; shift 2 ;;
    --preview-glass) require_arg "$1" "${2:-}"; PREVIEW_GLASS="$2"; shift 2 ;;
    --diagnose-summary) require_arg "$1" "${2:-}"; DIAGNOSE_SUMMARY="$2"; shift 2 ;;
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

append_success_records
