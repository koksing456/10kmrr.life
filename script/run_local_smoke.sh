#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
APPLY=false
FULL_RESET=false
RECORD=false
SELF_TEST=false

BUILD_VERIFY="not_run"
INSTALL_AGENT="not_run"
DIAGNOSE_AFTER_INSTALL="not_run"
REPAIR_PRESERVES_DATA="not_run"
SUPPORT_REPORT_SAFE="not_run"
UNINSTALL_ALL="not_run"
RESULT="warn"
BLOCKER=""
NEXT_ACTION="review local smoke output"

usage() {
  cat <<EOF
Usage: $0 [--apply] [--full-reset] [--record] [--tracker-dir DIR] [--self-test] [--help]

Runs or previews the local private-beta smoke sequence.

Default mode prints the steps without changing local state. Use --apply to run
the smoke sequence. Use --full-reset only on a clean/private-beta smoke machine;
it runs uninstall with --all and removes local cache, display settings, and the
stored Stripe key. Use --record to append a safe local-smoke row after the run.

Options:
  --apply            Execute the smoke sequence.
  --full-reset       Final uninstall uses --all. Required for a full pass row.
  --record           Record pass/warn/fail evidence after an applied run.
  --tracker-dir DIR  Tracker directory. Default: build/alpha-tracker.
  --self-test        Verify planning and option safety without changing state.
  --help             Show this help.
EOF
}

section() {
  printf '\n==> %s\n' "$1"
}

status_line() {
  local level="$1"
  local message="$2"
  printf '%-5s %s\n' "$level" "$message"
}

run_or_preview() {
  if [[ "$APPLY" == "true" ]]; then
    "$@"
  else
    printf 'DRY-RUN  %s\n' "$*"
  fi
}

run_applied_step() {
  local status_var="$1"
  shift

  if "$@"; then
    printf -v "$status_var" 'pass'
    return 0
  fi

  printf -v "$status_var" 'fail'
  RESULT="fail"
  BLOCKER="${BLOCKER:-command failed: $*}"
  return 1
}

set_warning_status() {
  local status_var="$1"
  local blocker_message="$2"

  printf -v "$status_var" 'warn'
  if [[ "$RESULT" != "fail" ]]; then
    RESULT="warn"
  fi
  BLOCKER="${BLOCKER:-$blocker_message}"
}

run_checked_output_step() {
  local status_var="$1"
  local temp_output command_status first_issue
  shift

  temp_output="$(/usr/bin/mktemp -t 10kmrr-smoke-output.XXXXXX)"
  set +e
  "$@" 2>&1 | /usr/bin/tee "$temp_output"
  command_status="${PIPESTATUS[0]}"
  set -e

  if [[ "$command_status" -ne 0 ]]; then
    printf -v "$status_var" 'fail'
    RESULT="fail"
    BLOCKER="${BLOCKER:-command failed: $*}"
    /bin/rm -f "$temp_output"
    return 1
  fi

  if /usr/bin/grep -Eq '^FAIL[[:space:]]' "$temp_output"; then
    first_issue="$(/usr/bin/grep -E '^FAIL[[:space:]]' "$temp_output" | /usr/bin/head -1 | /usr/bin/tr -s '[:space:]' ' ' | /usr/bin/sed 's/[[:space:]]*$//')"
    printf -v "$status_var" 'fail'
    RESULT="fail"
    BLOCKER="${BLOCKER:-$first_issue}"
    /bin/rm -f "$temp_output"
    return 1
  fi

  if /usr/bin/grep -Eq '^WARN[[:space:]]' "$temp_output"; then
    first_issue="$(/usr/bin/grep -E '^WARN[[:space:]]' "$temp_output" | /usr/bin/head -1 | /usr/bin/tr -s '[:space:]' ' ' | /usr/bin/sed 's/[[:space:]]*$//')"
    set_warning_status "$status_var" "$first_issue"
    /bin/rm -f "$temp_output"
    return 0
  fi

  printf -v "$status_var" 'pass'
  /bin/rm -f "$temp_output"
  return 0
}

print_plan() {
  section "Local smoke plan"
  run_or_preview "$ROOT_DIR/script/build_lock_overlay.sh" --verify
  run_or_preview "$ROOT_DIR/script/install_lock_overlay_agent.sh"
  run_or_preview "$ROOT_DIR/script/diagnose.sh"
  run_or_preview "$ROOT_DIR/script/repair_lock_overlay_agent.sh"
  run_or_preview "$ROOT_DIR/script/support_report.sh"

  if [[ "$FULL_RESET" == "true" ]]; then
    run_or_preview "$ROOT_DIR/script/uninstall_lock_overlay_agent.sh" --all
  else
    run_or_preview "$ROOT_DIR/script/uninstall_lock_overlay_agent.sh"
  fi

  if [[ "$APPLY" != "true" ]]; then
    status_line "INFO" "no local state changed"
    status_line "NEXT" "run with --apply to execute; add --full-reset only on a clean smoke machine"
  fi
}

run_smoke() {
  section "Build verify"
  if ! run_applied_step BUILD_VERIFY "$ROOT_DIR/script/build_lock_overlay.sh" --verify; then
    status_line "FAIL" "build verify failed; skipping install-dependent smoke steps"
    return
  fi

  section "Install LaunchAgent"
  if ! run_applied_step INSTALL_AGENT "$ROOT_DIR/script/install_lock_overlay_agent.sh"; then
    status_line "FAIL" "install failed; skipping install-dependent smoke steps"
    return
  fi

  section "Diagnose after install"
  run_checked_output_step DIAGNOSE_AFTER_INSTALL "$ROOT_DIR/script/diagnose.sh" || true

  section "Repair preserves local data"
  run_checked_output_step REPAIR_PRESERVES_DATA "$ROOT_DIR/script/repair_lock_overlay_agent.sh" || true

  section "Support report safety"
  run_checked_output_step SUPPORT_REPORT_SAFE "$ROOT_DIR/script/support_report.sh" || true

  section "Uninstall"
  if [[ "$FULL_RESET" == "true" ]]; then
    run_applied_step UNINSTALL_ALL "$ROOT_DIR/script/uninstall_lock_overlay_agent.sh" --all || true
  else
    "$ROOT_DIR/script/uninstall_lock_overlay_agent.sh" || true
    UNINSTALL_ALL="not_run"
    RESULT="warn"
    NEXT_ACTION="rerun on clean smoke machine with --full-reset"
  fi
}

compute_result() {
  if [[ "$BUILD_VERIFY" == "pass" &&
        "$INSTALL_AGENT" == "pass" &&
        "$DIAGNOSE_AFTER_INSTALL" == "pass" &&
        "$REPAIR_PRESERVES_DATA" == "pass" &&
        "$SUPPORT_REPORT_SAFE" == "pass" &&
        "$UNINSTALL_ALL" == "pass" ]]; then
    RESULT="pass"
    NEXT_ACTION="ready for beta gate"
    return
  fi

  if [[ "$RESULT" != "fail" ]]; then
    RESULT="warn"
  fi
}

print_summary() {
  section "Local smoke summary"
  status_line "INFO" "build verify: $BUILD_VERIFY"
  status_line "INFO" "install agent: $INSTALL_AGENT"
  status_line "INFO" "diagnose after install: $DIAGNOSE_AFTER_INSTALL"
  status_line "INFO" "repair preserves data: $REPAIR_PRESERVES_DATA"
  status_line "INFO" "support report safe: $SUPPORT_REPORT_SAFE"
  status_line "INFO" "uninstall all: $UNINSTALL_ALL"
  status_line "INFO" "result: $RESULT"
  if [[ -n "$BLOCKER" ]]; then
    status_line "INFO" "blocker: $BLOCKER"
  fi
  status_line "INFO" "next action: $NEXT_ACTION"
}

record_summary() {
  "$ROOT_DIR/script/record_alpha_local_smoke.sh" \
    --tracker-dir "$TRACKER_DIR" \
    --build-verify "$BUILD_VERIFY" \
    --install-agent "$INSTALL_AGENT" \
    --diagnose-after-install "$DIAGNOSE_AFTER_INSTALL" \
    --repair-preserves-data "$REPAIR_PRESERVES_DATA" \
    --support-report-safe "$SUPPORT_REPORT_SAFE" \
    --uninstall-all "$UNINSTALL_ALL" \
    --result "$RESULT" \
    --blocker "$BLOCKER" \
    --next-action "$NEXT_ACTION"
}

self_test() {
  local output full_output record_error

  output="$("$0")"
  printf '%s\n' "$output" | /usr/bin/grep -q 'DRY-RUN  .*/script/build_lock_overlay.sh --verify'
  printf '%s\n' "$output" | /usr/bin/grep -q 'DRY-RUN  .*/script/uninstall_lock_overlay_agent.sh$'
  if printf '%s\n' "$output" | /usr/bin/grep -q -- '--all'; then
    printf 'run_local_smoke self-test failed: default plan included --all.\n' >&2
    exit 1
  fi

  full_output="$("$0" --full-reset)"
  printf '%s\n' "$full_output" | /usr/bin/grep -q 'DRY-RUN  .*/script/uninstall_lock_overlay_agent.sh --all'

  if "$0" --record >/tmp/10kmrr-run-smoke-record.$$ 2>&1; then
    printf 'run_local_smoke self-test failed: --record without --apply was accepted.\n' >&2
    /bin/rm -f /tmp/10kmrr-run-smoke-record.$$
    exit 1
  fi
  record_error="$(cat /tmp/10kmrr-run-smoke-record.$$)"
  /bin/rm -f /tmp/10kmrr-run-smoke-record.$$
  printf '%s\n' "$record_error" | /usr/bin/grep -q 'Use --record only with --apply'

  RESULT="warn"
  BLOCKER=""
  BUILD_VERIFY="not_run"
  run_checked_output_step BUILD_VERIFY /bin/sh -c 'printf "WARN  synthetic command warning\n"' >/tmp/10kmrr-run-smoke-warn.$$ 2>&1
  [[ "$BUILD_VERIFY" == "warn" ]]
  [[ "$RESULT" == "warn" ]]
  [[ "$BLOCKER" == 'WARN synthetic command warning' ]]
  /bin/rm -f /tmp/10kmrr-run-smoke-warn.$$

  RESULT="warn"
  BLOCKER=""
  INSTALL_AGENT="not_run"
  run_checked_output_step INSTALL_AGENT /bin/sh -c 'printf "FAIL  synthetic command failure\n"' >/tmp/10kmrr-run-smoke-fail.$$ 2>&1 || true
  [[ "$INSTALL_AGENT" == "fail" ]]
  [[ "$RESULT" == "fail" ]]
  [[ "$BLOCKER" == 'FAIL synthetic command failure' ]]
  /bin/rm -f /tmp/10kmrr-run-smoke-fail.$$

  printf 'Local smoke runner self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=true
      shift
      ;;
    --full-reset)
      FULL_RESET=true
      shift
      ;;
    --record)
      RECORD=true
      shift
      ;;
    --tracker-dir)
      if [[ $# -lt 2 || "${2:-}" == --* ]]; then
        printf 'Missing value for --tracker-dir.\n' >&2
        exit 64
      fi
      TRACKER_DIR="$2"
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

cd "$ROOT_DIR"

if [[ "$SELF_TEST" == "true" ]]; then
  self_test
  exit 0
fi

if [[ "$RECORD" == "true" && "$APPLY" != "true" ]]; then
  printf 'Use --record only with --apply so evidence reflects a real run.\n' >&2
  exit 64
fi

if [[ "$APPLY" != "true" ]]; then
  print_plan
  exit 0
fi

run_smoke
compute_result
print_summary

if [[ "$RECORD" == "true" ]]; then
  section "Record local smoke evidence"
  record_summary
else
  status_line "NEXT" "add --record to append this run to the private tracker"
fi
