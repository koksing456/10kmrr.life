#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERBOSE=false
SKIP_SIGNING=false

usage() {
  cat <<EOF
Usage: $0 [--verbose] [--no-signing] [--self-test] [--help]

Prints a safe alpha health triage summary for local install/support issues.
It does not print Stripe keys, exact MRR, raw logs, raw Stripe responses,
customer/payment data, contact data, or Stripe object IDs.

Options:
  --verbose     Include sanitized diagnostic detail after the summary.
  --no-signing  Skip Developer ID/notary readiness check.
  --self-test   Verify triage and redaction behavior with synthetic output.
  --help        Show this help.
EOF
}

status_line() {
  printf '%-5s %s\n' "$1" "$2"
}

section() {
  printf '\n==> %s\n' "$1"
}

sanitize_stream() {
  HOME_PATH="$HOME" ROOT_PATH="$ROOT_DIR" /usr/bin/perl -pe '
    BEGIN {
      $home = quotemeta($ENV{"HOME_PATH"} // "");
      $root = quotemeta($ENV{"ROOT_PATH"} // "");
    }
    s/$root/<repo>/g if $root ne "";
    s/$home/<home>/g if $home ne "";
    s/\b[rs]k_(?:live|test)_[A-Za-z0-9_]+\b/<redacted-stripe-key>/g;
    s/\bwhsec_[A-Za-z0-9_]+\b/<redacted-webhook-secret>/g;
    s/\b(?:cus|sub|si|seti|price|prod|in|pi|pm|cs|ch)_[A-Za-z0-9_]+\b/<redacted-stripe-object-id>/g;
    s/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/<redacted-email>/gi;
    s/\b[A-Z]{2,4}\$[0-9][0-9,]*(?:\.[0-9]{2})?\b/<redacted-money>/g;
    s/\b[A-Z]{3}\s+[0-9][0-9,]*(?:\.[0-9]{2})?\b/<redacted-money>/g;
    s/\$[0-9][0-9,]*(?:\.[0-9]{2})?\b/<redacted-money>/g;
    s/\b(?:MRR|ARR|revenue|amount)\s*[:=]?\s*[0-9][0-9,]*(?:\.[0-9]{2})?\b/<redacted-money>/gi;
  '
}

contains() {
  local text="$1"
  local pattern="$2"
  printf '%s\n' "$text" | /usr/bin/grep -Eq "$pattern"
}

count_status() {
  local text="$1"
  local status="$2"
  printf '%s\n' "$text" | /usr/bin/awk -v status="$status" '$1 == status { count++ } END { print count + 0 }'
}

emit_local_triage() {
  local diagnostic="$1"
  local pass_count warn_count fail_count
  pass_count="$(count_status "$diagnostic" PASS)"
  warn_count="$(count_status "$diagnostic" WARN)"
  fail_count="$(count_status "$diagnostic" FAIL)"

  section "Local Overlay"
  status_line "INFO" "diagnostic summary: ${pass_count} pass, ${warn_count} warn, ${fail_count} fail"

  if contains "$diagnostic" 'Build artifact missing'; then
    status_line "WARN" "local build artifact is missing"
    status_line "NEXT" "build and verify: ./script/build_lock_overlay.sh --verify"
  else
    status_line "PASS" "local build artifact check did not report a missing build"
  fi

  if contains "$diagnostic" 'Stripe key missing'; then
    status_line "WARN" "restricted Stripe key is not configured in Keychain"
    status_line "NEXT" "open setup and save a restricted read-only key: ./script/build_lock_overlay.sh --setup"
  elif contains "$diagnostic" 'legacy Keychain service'; then
    status_line "WARN" "legacy Keychain key exists and should be migrated by setup/app read"
    status_line "NEXT" "open setup, refresh MRR, then rerun: ./script/alpha.sh health"
  else
    status_line "PASS" "Keychain check did not report a missing Stripe key"
  fi

  if contains "$diagnostic" 'Installed app missing|LaunchAgent plist missing|LaunchAgent is not loaded'; then
    status_line "WARN" "installed app or LaunchAgent is not ready"
    status_line "NEXT" "run guided start if this is a tester: ./script/alpha.sh start --tester-id tester_XXX"
    status_line "NEXT" "or install directly after setup is ready: ./script/install_lock_overlay_agent.sh"
  elif contains "$diagnostic" 'LaunchAgent executable mismatch|missing --private-glass|log paths are unexpected|Source checkout marker'; then
    status_line "WARN" "installed LaunchAgent/source marker drift detected"
    status_line "NEXT" "repair while preserving Keychain/cache/settings: ./script/repair_lock_overlay_agent.sh"
  else
    status_line "PASS" "install and LaunchAgent checks did not report required repair"
  fi

  if contains "$diagnostic" 'No last-good MRR cache yet|No last-updated timestamp yet'; then
    status_line "WARN" "last-good MRR cache is not ready yet"
    status_line "NEXT" "refresh MRR from setup after saving the restricted key"
  else
    status_line "PASS" "cache check did not report a missing last-good MRR value"
  fi

  if [[ "$warn_count" -eq 0 && "$fail_count" -eq 0 ]]; then
    status_line "NEXT" "lock the Mac and visually confirm the overlay appears and hides after unlock"
  fi

  status_line "NEXT" "preview without locking: ./script/build_lock_overlay.sh --preview-private-glass"
}

emit_signing_triage() {
  local signing_output="$1"

  section "Signing"
  if contains "$signing_output" '^PASS  Developer ID Application identity is available' && contains "$signing_output" '^PASS  Notary keychain profile is available'; then
    status_line "PASS" "Developer ID signing prerequisites appear ready"
    status_line "NEXT" "after evidence gates pass, build private package: ./script/alpha.sh package --signed"
  else
    status_line "WARN" "Developer ID signed/notarized beta is not ready"
    status_line "NEXT" "details: ./script/alpha.sh signing"
  fi
}

emit_support_triage() {
  section "Support Boundary"
  status_line "NEXT" "generate sanitized report for support: ./script/alpha.sh support-report"
  status_line "RULE" "share sanitized support reports or pass/warn/fail summaries only"
  status_line "RULE" "do not collect Stripe keys, Stripe object IDs, exact MRR, raw logs, raw Stripe responses, customer/payment data, contact data, or unsanitized screenshots"
}

emit_health() {
  local diagnostic="$1"
  local signing_output="${2:-}"

  printf '10kmrr.life alpha health triage\n'
  emit_local_triage "$diagnostic"
  if [[ "$SKIP_SIGNING" != "true" ]]; then
    emit_signing_triage "$signing_output"
  fi
  emit_support_triage

  if [[ "$VERBOSE" == "true" ]]; then
    section "Sanitized Diagnostic Detail"
    printf '%s\n' "$diagnostic" | sanitize_stream
  fi
}

self_test() {
  local output secret_output clean_output

  output="$(emit_health 'PASS  Build artifact exists: /tmp/build.app
WARN  Stripe key missing. Run ./script/build_lock_overlay.sh --setup
WARN  LaunchAgent is not loaded.
WARN  No last-good MRR cache yet.' 'WARN  Developer ID Application identity not found.')"
  printf '%s\n' "$output" | /usr/bin/grep -q '10kmrr.life alpha health triage'
  printf '%s\n' "$output" | /usr/bin/grep -q './script/build_lock_overlay.sh --setup'
  printf '%s\n' "$output" | /usr/bin/grep -q './script/install_lock_overlay_agent.sh'
  printf '%s\n' "$output" | /usr/bin/grep -q './script/alpha.sh support-report'
  printf '%s\n' "$output" | /usr/bin/grep -q 'Stripe object IDs'

  clean_output="$(emit_health 'PASS  Build artifact exists
PASS  Stripe key exists in Keychain. Key value was not printed.
PASS  LaunchAgent is loaded.
PASS  Last-good MRR cache exists. Cached value was not printed.' 'PASS  Developer ID Application identity is available.
PASS  Notary keychain profile is available.')"
  printf '%s\n' "$clean_output" | /usr/bin/grep -q 'lock the Mac and visually confirm'
  printf '%s\n' "$clean_output" | /usr/bin/grep -q './script/alpha.sh package --signed'

  secret_output="$(
    {
      printf 'repo=%s\n' "$ROOT_DIR"
      printf 'home=%s\n' "$HOME"
      printf 'key=rk_%s_%s\n' 'live' '1234567890abcdef'
      printf 'customer=cus_%s\n' '1234567890abcdef'
      printf 'email=founder@example.com\n'
      printf 'mrr=US$10,248.00\n'
    } | sanitize_stream
  )"
  if printf '%s\n' "$secret_output" | /usr/bin/grep -F "$ROOT_DIR" >/dev/null; then
    printf 'alpha health self-test failed: repo path was not redacted.\n' >&2
    exit 1
  fi
  if printf '%s\n' "$secret_output" | /usr/bin/grep -F "$HOME" >/dev/null; then
    printf 'alpha health self-test failed: HOME path was not redacted.\n' >&2
    exit 1
  fi
  if printf '%s\n' "$secret_output" | /usr/bin/grep -Eq 'rk_live_|cus_[A-Za-z0-9]+|founder@example\.com|US\$10,248\.00'; then
    printf 'alpha health self-test failed: sensitive-looking output was not redacted.\n' >&2
    exit 1
  fi

  printf 'Alpha health triage self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      VERBOSE=true
      shift
      ;;
    --no-signing)
      SKIP_SIGNING=true
      shift
      ;;
    --self-test)
      self_test
      exit 0
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

DIAGNOSTIC_OUTPUT="$("$ROOT_DIR/script/diagnose.sh" 2>&1 | sanitize_stream || true)"
SIGNING_OUTPUT=""
if [[ "$SKIP_SIGNING" != "true" ]]; then
  SIGNING_OUTPUT="$("$ROOT_DIR/script/signing_preflight.sh" --require-ready 2>&1 | sanitize_stream || true)"
fi

emit_health "$DIAGNOSTIC_OUTPUT" "$SIGNING_OUTPUT"
