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

The report redacts local HOME/repo paths, Stripe-key-like strings, Stripe object
IDs, raw Stripe field names, email-like contact data, and obvious money amounts.
By default it does not include log excerpts.

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
    s/\b(?:cus|sub|si|seti|price|prod|in|pi|pm|cs|ch)_[A-Za-z0-9_]+\b/<redacted-stripe-object-id>/g;
    s/\b(?:client_secret|hosted_invoice_url|invoice_pdf|payment_method|customer_email)\b/<redacted-stripe-field>/g;
    s/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/<redacted-email>/gi;
    s/\b[A-Z]{2,4}\$[0-9][0-9,]*(?:\.[0-9]{2})?\b/<redacted-money>/g;
    s/\b[A-Z]{3}\s+[0-9][0-9,]*(?:\.[0-9]{2})?\b/<redacted-money>/g;
    s/\$[0-9][0-9,]*(?:\.[0-9]{2})?\b/<redacted-money>/g;
    s/\b(?:MRR|ARR|revenue|amount)\s*[:=]?\s*[0-9][0-9,]*(?:\.[0-9]{2})?\b/<redacted-money>/gi;
  '
}

diagnose_output() {
  "$ROOT_DIR/script/diagnose.sh" 2>&1 | sanitize_stream
}

print_next_steps() {
  local diagnostic="$1"

  printf '\n## Suggested Next Steps\n\n'

  if printf '%s\n' "$diagnostic" | /usr/bin/grep -Eq 'Stripe key missing'; then
    printf -- '- Open setup and save a restricted read-only Stripe key: `./script/build_lock_overlay.sh --setup`.\n'
  fi

  if printf '%s\n' "$diagnostic" | /usr/bin/grep -Eq 'legacy Keychain service'; then
    printf -- '- A legacy Stripe key exists. Open setup or restart the overlay after repair so the app can migrate it to the current Keychain service.\n'
  fi

  if printf '%s\n' "$diagnostic" | /usr/bin/grep -Eq 'LaunchAgent is not loaded|LaunchAgent executable mismatch|missing --private-glass|log paths are unexpected|LaunchAgent plist missing|Installed app missing'; then
    printf -- '- Repair app and LaunchAgent while preserving Keychain/cache/settings: `./script/repair_lock_overlay_agent.sh`.\n'
  fi

  if printf '%s\n' "$diagnostic" | /usr/bin/grep -Eq 'Build artifact missing'; then
    printf -- '- Rebuild and verify the local app: `./script/build_lock_overlay.sh --verify`.\n'
  fi

  if printf '%s\n' "$diagnostic" | /usr/bin/grep -Eq 'No last-good MRR cache yet|No last-updated timestamp yet'; then
    printf -- '- After configuring a key, refresh MRR from setup to create the local last-good cache.\n'
  fi

  printf -- '- For source/build issues, run the full local readiness check: `./script/alpha.sh check`.\n'
  printf -- '- Share only this sanitized report or pass/warn/fail summaries. Do not add Stripe keys, exact MRR, raw Stripe responses, customer data, or unsanitized revenue screenshots.\n'
}

self_test() {
  local output next_steps
  output="$(
    {
      printf 'home=%s\n' "$HOME"
      printf 'repo=%s\n' "$ROOT_DIR"
      printf 'stripe=rk_%s_%s\n' 'live' '1234567890abcdef'
      printf 'stripe=sk_%s_%s\n' 'test' '1234567890abcdef'
      printf 'webhook=whsec_%s\n' '1234567890abcdef'
      printf 'customer=cus_%s\n' '1234567890abcdef'
      printf 'subscription=sub_%s\n' '1234567890abcdef'
      printf 'charge=ch_%s\n' '1234567890abcdef'
      printf 'setup_intent=seti_%s\n' '1234567890abcdef'
      printf 'client_secret=pi_%s_secret_%s\n' '1234567890abcdef' '1234567890abcdef'
      printf 'invoice_pdf=https://pay.stripe.com/invoice/test\n'
      printf 'customer_email=founder@example.com\n'
      printf 'email=founder@example.com\n'
      printf 'mrr=US$10,248.00\n'
      printf 'mrr=USD 10248.00\n'
      printf 'mrr=$10,248.00\n'
      printf 'mrr=MRR 10248.00\n'
      printf 'arr=ARR: 120000\n'
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
  if printf '%s\n' "$output" | /usr/bin/grep -Eq '\b(cus|sub|si|seti|price|prod|in|pi|pm|cs|ch)_[A-Za-z0-9_]+'; then
    printf 'Support report self-test failed: Stripe object id was not redacted.\n' >&2
    exit 1
  fi
  if printf '%s\n' "$output" | /usr/bin/grep -Eq '\b(client_secret|hosted_invoice_url|invoice_pdf|payment_method|customer_email)\b'; then
    printf 'Support report self-test failed: raw Stripe field name was not redacted.\n' >&2
    exit 1
  fi
  if printf '%s\n' "$output" | /usr/bin/grep -Eq 'founder@example\.com'; then
    printf 'Support report self-test failed: email-like value was not redacted.\n' >&2
    exit 1
  fi
  if printf '%s\n' "$output" | /usr/bin/grep -Eq '(US\$10,248\.00|USD 10248\.00|\$10,248\.00|MRR 10248\.00|ARR: 120000)'; then
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
  if ! printf '%s\n' "$output" | /usr/bin/grep -q '<redacted-stripe-object-id>'; then
    printf 'Support report self-test failed: Stripe object id redaction marker missing.\n' >&2
    exit 1
  fi
  if ! printf '%s\n' "$output" | /usr/bin/grep -q '<redacted-email>'; then
    printf 'Support report self-test failed: email redaction marker missing.\n' >&2
    exit 1
  fi
  if ! printf '%s\n' "$output" | /usr/bin/grep -q '<redacted-stripe-field>'; then
    printf 'Support report self-test failed: raw Stripe field redaction marker missing.\n' >&2
    exit 1
  fi

  next_steps="$(print_next_steps 'WARN  LaunchAgent is not loaded.
WARN  Stripe key missing.
WARN  No last-good MRR cache yet.' | sanitize_stream)"
  if ! printf '%s\n' "$next_steps" | /usr/bin/grep -q './script/repair_lock_overlay_agent.sh'; then
    printf 'Support report self-test failed: repair next step missing.\n' >&2
    exit 1
  fi
  if ! printf '%s\n' "$next_steps" | /usr/bin/grep -q './script/alpha.sh check'; then
    printf 'Support report self-test failed: check next step missing.\n' >&2
    exit 1
  fi
  if printf '%s\n' "$next_steps" | /usr/bin/grep -Eq '[rs]k_(live|test)_[A-Za-z0-9_]+|US\$[0-9]'; then
    printf 'Support report self-test failed: next steps contained sensitive-looking output.\n' >&2
    exit 1
  fi

  printf 'Support report redaction self-test passed.\n'
}

if [[ "$SELF_TEST" == "true" ]]; then
  self_test
  exit 0
fi

DIAGNOSTIC_OUTPUT="$(diagnose_output)"

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
  printf 'Report safety: paths, Stripe-key-like strings, Stripe object IDs, raw Stripe field names, email-like contact data, webhook secrets, and obvious money amounts are redacted.\n'
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

  {
    printf '\n## Diagnostic\n\n'
    printf '%s\n' "$DIAGNOSTIC_OUTPUT"
  } | sanitize_stream

  print_next_steps "$DIAGNOSTIC_OUTPUT" | sanitize_stream

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
    printf 'Not included. Rerun with --include-logs only after confirming the tester did not capture sensitive output; included excerpts are still redacted.\n'
  fi
} >"$REPORT_PATH"

printf 'Wrote sanitized support report:\n'
printf '  %s\n' "$REPORT_PATH"
