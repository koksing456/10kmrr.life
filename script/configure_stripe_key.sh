#!/usr/bin/env bash
set -euo pipefail

KEYCHAIN_SERVICE="life.10kmrr.StripeMRRScreenSaver"
KEYCHAIN_ACCOUNT="stripe_api_key"

usage() {
  cat <<EOF
Usage: $0 [--status|--delete|--help]

Stores the Stripe restricted API key used by MRRLockScreenOverlay in macOS Keychain.
The key is never printed by this script.

Options:
  --status   Check whether a key exists without printing it.
  --delete   Remove the stored key.
  --help     Show this help.
EOF
}

key_exists() {
  /usr/bin/security find-generic-password \
    -s "$KEYCHAIN_SERVICE" \
    -a "$KEYCHAIN_ACCOUNT" \
    >/dev/null 2>&1
}

case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
  --status)
    if key_exists; then
      printf 'Stripe key status: configured in Keychain.\n'
    else
      printf 'Stripe key status: not configured.\n'
      exit 1
    fi
    exit 0
    ;;
  --delete)
    if key_exists; then
      /usr/bin/security delete-generic-password \
        -s "$KEYCHAIN_SERVICE" \
        -a "$KEYCHAIN_ACCOUNT" \
        >/dev/null
      printf 'Removed Stripe key from Keychain.\n'
    else
      printf 'No Stripe key was configured.\n'
    fi
    exit 0
    ;;
  "")
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac

printf 'Paste your Stripe restricted read-only API key. Input will be hidden.\n'
printf 'Recommended prefix: rk_live_ or rk_test_. Do not use a full-access sk_live_ key.\n'
IFS= read -rsp "Stripe restricted key: " stripe_key
printf '\n'

if [[ -z "$stripe_key" ]]; then
  printf 'No key entered. Nothing changed.\n' >&2
  exit 64
fi

if [[ "$stripe_key" == sk_* ]]; then
  printf 'Refusing to store a full-access Stripe secret key. Create a restricted read-only key instead.\n' >&2
  exit 65
fi

if [[ "$stripe_key" != rk_* ]]; then
  printf 'Warning: key does not start with rk_. Continuing because Stripe key prefixes may change.\n' >&2
fi

/usr/bin/security add-generic-password \
  -U \
  -s "$KEYCHAIN_SERVICE" \
  -a "$KEYCHAIN_ACCOUNT" \
  -w "$stripe_key" \
  >/dev/null

printf 'Stored Stripe key in macOS Keychain for MRRLockScreenOverlay.\n'
