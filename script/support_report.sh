#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SUPPORT="$HOME/Library/Application Support/10kmrr.life"
OUT_LOG="$APP_SUPPORT/logs/mrr-lock-overlay.out.log"
ERR_LOG="$APP_SUPPORT/logs/mrr-lock-overlay.err.log"
REPORT_DIR="$ROOT_DIR/build/support"
REPORT_PATH="$REPORT_DIR/10kmrr-support-report.txt"
INCLUDE_LOGS=false
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 [--include-logs] [--self-test] [--help]

Writes a sanitized local support report to:
  build/support/10kmrr-support-report.txt

The report redacts local HOME/repo paths, Stripe-key-like strings, and obvious
money amounts. By default it does not include raw log contents.

Options:
  --include-logs  Include the last safe-redacted stdout/stderr log lines.
  --self-test     Verify redaction rules with synthetic sensitive samples.
  --help          Show this help.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --include-logs)
      INCLUDE_LOGS=true
      ;;
    --self-test)
      SELF_TEST=true
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

mkdir -p "$REPORT_DIR"

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
    s/\b[A-Z]{2,4}\$[0-9][0-9,]*(?:\.[0-9]{2})?\b/<redacted-money>/g;
    s/\b[A-Z]{3}\s+[0-9][0-9,]*(?:\.[0-9]{2})?\b/<redacted-money>/g;
  '
}

self_test() {
  local output
  output="$(
    {
      printf 'home=%s\n' "$HOME"
      printf 'repo=%s\n' "$ROOT_DIR"
      printf 'stripe=rk_%s_%s\n' 'live' '1234567890abcdef'
      printf 'stripe=sk_%s_%s\n' 'test' '1234567890abcdef'
      printf 'webhook=whsec_%s\n' '1234567890abcdef'
      printf 'mrr=US$10,248.00\n'
      printf 'mrr=USD 10248.00\n'
    } | sanitize_stream
  )"

  if printf '%s\n' "$output" | /usr/bin/grep -F "$HOME" >/dev/null; then
    printf 'Support report self-test failed: HOME path was not redacted.\n' >&2
    exit 1
  fi
  if printf '%s\n' "$output" | /usr/bin/grep -F "$ROOT_DIR" >/dev/null; then
    printf 'Support report self-test failed: repo path was not redacted.\n' >&2
    exit 1
  fi
  if printf '%s\n' "$output" | /usr/bin/grep -Eq '[rs]k_(live|test)_[A-Za-z0-9_]+'; then
    printf 'Support report self-test failed: Stripe-key-like value was not redacted.\n' >&2
    exit 1
  fi
  if printf '%s\n' "$output" | /usr/bin/grep -Eq 'whsec_[A-Za-z0-9_]+'; then
    printf 'Support report self-test failed: webhook secret-like value was not redacted.\n' >&2
    exit 1
  fi
  if printf '%s\n' "$output" | /usr/bin/grep -Eq '(US\$10,248\.00|USD 10248\.00)'; then
    printf 'Support report self-test failed: obvious money amount was not redacted.\n' >&2
    exit 1
  fi
  if ! printf '%s\n' "$output" | /usr/bin/grep -q '<redacted-stripe-key>'; then
    printf 'Support report self-test failed: Stripe redaction marker missing.\n' >&2
    exit 1
  fi
  if ! printf '%s\n' "$output" | /usr/bin/grep -q '<redacted-money>'; then
    printf 'Support report self-test failed: money redaction marker missing.\n' >&2
    exit 1
  fi

  printf 'Support report redaction self-test passed.\n'
}

if [[ "$SELF_TEST" == "true" ]]; then
  self_test
  exit 0
fi

run_section() {
  local title="$1"
  shift
  {
    printf '\n## %s\n\n' "$title"
    "$@" 2>&1 || true
  } | sanitize_stream
}

{
  printf '# 10kmrr.life Sanitized Support Report\n'
  printf '\nGenerated: %s\n' "$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf 'Report safety: paths, Stripe-key-like strings, webhook secrets, and obvious money amounts are redacted.\n'
  printf 'Raw Stripe keys, exact private MRR, raw Stripe responses, customer data, and payment data should never be added manually.\n'

  run_section "System" /bin/sh -c '
    /usr/bin/sw_vers
    printf "Architecture: "
    /usr/bin/uname -m
  '

  run_section "Git" /bin/sh -c '
    cd "$1"
    printf "Commit: "
    /usr/bin/git rev-parse --short HEAD 2>/dev/null || true
    printf "Branch: "
    /usr/bin/git branch --show-current 2>/dev/null || true
    printf "Status:\n"
    /usr/bin/git status --short 2>/dev/null || true
  ' sh "$ROOT_DIR"

  run_section "Diagnostic" "$ROOT_DIR/script/diagnose.sh"

  run_section "Installed Log Metadata" /bin/sh -c '
    for log_path in "$1" "$2"; do
      if [ -f "$log_path" ]; then
        printf "%s exists, size=%s bytes\n" "$log_path" "$(/usr/bin/stat -f %z "$log_path")"
      else
        printf "%s missing\n" "$log_path"
      fi
    done
  ' sh "$OUT_LOG" "$ERR_LOG"

  if [[ "$INCLUDE_LOGS" == "true" ]]; then
    run_section "Recent Stdout Log" /usr/bin/tail -n 80 "$OUT_LOG"
    run_section "Recent Stderr Log" /usr/bin/tail -n 80 "$ERR_LOG"
  else
    printf '\n## Recent Logs\n\n'
    printf 'Not included. Rerun with --include-logs only after confirming the tester did not capture sensitive output.\n'
  fi
} >"$REPORT_PATH"

printf 'Wrote sanitized support report:\n'
printf '  %s\n' "$REPORT_PATH"
