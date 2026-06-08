#!/usr/bin/env bash
set -euo pipefail

TESTER_ID=""
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 --tester-id ID [--self-test] [--help]

Prints a safe gated-alpha invite message for one approved tester.
This script does not write tracker rows and never asks for Stripe keys.

Options:
  --tester-id ID  Required stable private tester id, such as tester_001.
  --self-test     Verify validation and output safety.
  --help          Show this help.
EOF
}

require_arg() {
  local option="$1"
  if [[ $# -lt 2 || "${2:-}" == --* ]]; then
    printf 'Missing value for %s.\n' "$option" >&2
    exit 64
  fi
}

validate_tester_id() {
  local value="$1"

  if [[ -z "$value" ]]; then
    printf 'Missing required --tester-id.\n' >&2
    exit 64
  fi

  if printf '%s\n' "$value" | /usr/bin/grep -Eq '[[:space:]]|[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+|([sr]k_(live|test)_|whsec_)|\b(cus|sub|price|prod|pi|ch|in|cs|pm|seti|si)_[A-Za-z0-9]{8,}\b|([Mm][Rr][Rr]|[Aa][Rr][Rr]|[Rr]evenue|[Aa]mount)[[:space:]:=]+[0-9]'; then
    printf 'Unsafe --tester-id. Use a stable private id like tester_001, not contact data, secrets, Stripe ids, or revenue values.\n' >&2
    exit 64
  fi
}

print_invite() {
  validate_tester_id "$TESTER_ID"

  cat <<EOF
Thanks for trying 10kmrr.life.

This is a source alpha, not a notarized public Mac app yet. It depends on private macOS behavior for Lock Screen placement, so compatibility is part of what we are testing.

Before setup:

- Read SECURITY.md.
- Use a restricted read-only Stripe key, not a full-access secret key.
- Enter the key only in the macOS setup window.
- Do not send Stripe keys, Stripe object IDs, exact MRR, raw Stripe responses, raw logs, customer/payment data, or unsanitized screenshots.

Setup path:

\`\`\`sh
./script/alpha.sh start --tester-id $TESTER_ID
\`\`\`

This opens the setup window and mock preview before installing. The setup flow stores the restricted key in macOS Keychain and refreshes MRR locally.

If something fails:

\`\`\`sh
./script/alpha.sh support-report
\`\`\`

Share only the sanitized support report summary or the failing section name. Use --include-logs only after checking the redacted excerpts do not contain sensitive output.

After setup works, send back only this safe reply format:

- MRR visible in the setup window: yes/no
- Lock Screen panel appears: yes/no
- Overlay hides after unlock: yes/no
- Display setup: built_in/external/multiple/clamshell/unknown
- macOS version: 15.x or unknown
- Blocker, if any: key/setup/refresh/lock_screen/unlock/launchagent/other/none
- Pro interest after first use: low/medium/high/unknown

Do not include exact MRR, Stripe keys, Stripe object IDs, raw Stripe responses, raw logs, customer/payment data, contact data, or unsanitized screenshots.

Day 7 question:

Would you keep MRR on your Lock Screen after the novelty wears off?
EOF
}

self_test() {
  local output live_env
  live_env="live"

  output="$("$0" --tester-id tester_001)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Thanks for trying 10kmrr.life'
  printf '%s\n' "$output" | /usr/bin/grep -q './script/alpha.sh start --tester-id tester_001'
  printf '%s\n' "$output" | /usr/bin/grep -q './script/alpha.sh support-report'
  printf '%s\n' "$output" | /usr/bin/grep -q 'Do not send Stripe keys, Stripe object IDs, exact MRR'
  printf '%s\n' "$output" | /usr/bin/grep -q 'Lock Screen panel appears: yes/no'
  printf '%s\n' "$output" | /usr/bin/grep -q 'safe reply format'
  printf '%s\n' "$output" | /usr/bin/grep -q 'Display setup: built_in/external/multiple/clamshell/unknown'
  printf '%s\n' "$output" | /usr/bin/grep -q 'Blocker, if any: key/setup/refresh/lock_screen/unlock/launchagent/other/none'
  printf '%s\n' "$output" | /usr/bin/grep -q 'Pro interest after first use: low/medium/high/unknown'

  if "$0" --tester-id 'founder@example.com' >/dev/null 2>&1; then
    printf 'generate_alpha_invite self-test failed: email-like tester id was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tester-id "rk_${live_env}_1234567890abcdef" >/dev/null 2>&1; then
    printf 'generate_alpha_invite self-test failed: secret-like tester id was accepted.\n' >&2
    exit 1
  fi

  if "$0" --tester-id 'MRR=10000' >/dev/null 2>&1; then
    printf 'generate_alpha_invite self-test failed: revenue-like tester id was accepted.\n' >&2
    exit 1
  fi

  if printf '%s\n' "$output" | /usr/bin/grep -Eq '(sk_live_|sk_test_|rk_live_|rk_test_|whsec_|cus_[A-Za-z0-9]+|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})'; then
    printf 'generate_alpha_invite self-test failed: output contained sensitive-looking data.\n' >&2
    exit 1
  fi

  printf 'Alpha invite generator self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tester-id) require_arg "$1" "${2:-}"; TESTER_ID="$2"; shift 2 ;;
    --self-test) SELF_TEST=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
done

if [[ "$SELF_TEST" == "true" ]]; then
  self_test
  exit 0
fi

print_invite
