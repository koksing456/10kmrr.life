#!/usr/bin/env bash
set -euo pipefail

REQUIRE_READY=false
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 [--require-ready] [--self-test] [--help]

Checks local signing/notarization prerequisites without reading or printing
notary credentials.

Default mode reports PASS/WARN and exits 0. Use --require-ready when you want
the command to fail unless Developer ID signing and notary tooling appear ready.

Options:
  --require-ready  Exit non-zero if release signing prerequisites are missing.
  --self-test      Verify local parser logic using synthetic identity output.
  --help           Show this help.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --require-ready)
      REQUIRE_READY=true
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

has_developer_id_application() {
  /usr/bin/grep -q '"Developer ID Application:'
}

self_test() {
  local sample_without sample_with missing_steps ready_steps
  sample_without='  1) ABCDEF "Apple Development: Example (TEAMID)"
     1 valid identities found'
  sample_with='  1) ABCDEF "Developer ID Application: Example, Inc. (TEAMID)"
  2) 123456 "Apple Development: Example (TEAMID)"
     2 valid identities found'

  if printf '%s\n' "$sample_without" | has_developer_id_application; then
    printf 'Signing preflight self-test failed: Apple Development identity counted as Developer ID.\n' >&2
    exit 1
  fi

  if ! printf '%s\n' "$sample_with" | has_developer_id_application; then
    printf 'Signing preflight self-test failed: Developer ID identity was not detected.\n' >&2
    exit 1
  fi

  missing_steps="$(suggested_steps "false" "false" "true")"
  printf '%s\n' "$missing_steps" | /usr/bin/grep -q 'Install Xcode'
  printf '%s\n' "$missing_steps" | /usr/bin/grep -q 'Developer ID Application certificate'
  printf '%s\n' "$missing_steps" | /usr/bin/grep -q 'Apple Development identity is not enough'

  ready_steps="$(suggested_steps "true" "true" "false")"
  printf '%s\n' "$ready_steps" | /usr/bin/grep -q './script/signing_preflight.sh --require-ready'
  printf '%s\n' "$ready_steps" | /usr/bin/grep -q './script/package_private_beta.sh --adhoc'

  printf 'Signing preflight self-test passed.\n'
}

suggested_steps() {
  local has_notarytool="$1"
  local has_developer_id="$2"
  local has_apple_development="$3"

  printf '\nSuggested signing next steps:\n'

  if [[ "$has_notarytool" != "true" ]]; then
    printf '  - Install Xcode or Xcode command line tools so xcrun notarytool is available.\n'
  fi

  if [[ "$has_developer_id" != "true" ]]; then
    printf '  - Create or install a Developer ID Application certificate in this Mac Keychain.\n'
    printf '  - Confirm it appears in: security find-identity -v -p codesigning\n'
  fi

  if [[ "$has_apple_development" == "true" && "$has_developer_id" != "true" ]]; then
    printf '  - Apple Development identity is not enough for Developer ID notarized distribution.\n'
  fi

  printf '  - Store notary credentials privately with xcrun notarytool store-credentials.\n'

  if [[ "$has_notarytool" == "true" && "$has_developer_id" == "true" ]]; then
    printf '  - Re-run strict readiness: ./script/signing_preflight.sh --require-ready\n'
    printf '  - Then run an internal dry run only: ./script/package_private_beta.sh --adhoc\n'
  fi
}

if [[ "$SELF_TEST" == "true" ]]; then
  self_test
  exit 0
fi

missing=0
has_notarytool=false
has_developer_id=false
has_apple_development=false

printf '10kmrr.life signing preflight\n'

if command -v xcrun >/dev/null 2>&1 && /usr/bin/xcrun notarytool --help >/dev/null 2>&1; then
  printf 'PASS  notarytool is available.\n'
  has_notarytool=true
else
  printf 'WARN  notarytool is not available. Install Xcode command line tools or Xcode.\n'
  missing=1
fi

identity_output="$(/usr/bin/security find-identity -v -p codesigning 2>/dev/null || true)"
if printf '%s\n' "$identity_output" | has_developer_id_application; then
  printf 'PASS  Developer ID Application identity is available.\n'
  has_developer_id=true
else
  printf 'WARN  Developer ID Application identity not found. Private signed/notarized packaging is not ready.\n'
  missing=1
fi

if printf '%s\n' "$identity_output" | /usr/bin/grep -q '"Apple Development:'; then
  printf 'INFO  Apple Development identity exists, but it is not enough for Developer ID notarized distribution.\n'
  has_apple_development=true
fi

printf 'INFO  Notary credentials are not checked or printed by this script. Store them privately with xcrun notarytool store-credentials.\n'
suggested_steps "$has_notarytool" "$has_developer_id" "$has_apple_development"

if [[ "$REQUIRE_READY" == "true" && "$missing" -ne 0 ]]; then
  exit 1
fi
