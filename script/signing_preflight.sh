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
Set TENKMRR_NOTARY_PROFILE to the private notarytool keychain profile name when
checking notarization readiness.

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

verify_notary_profile() {
  local profile="$1"
  local output_file="$2"

  [[ -n "$profile" ]] || return 1
  /usr/bin/xcrun notarytool history \
    --keychain-profile "$profile" \
    --output-format json \
    --no-progress \
    >"$output_file" 2>&1
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

  missing_steps="$(suggested_steps "false" "false" "true" "false")"
  printf '%s\n' "$missing_steps" | /usr/bin/grep -q 'Install Xcode'
  printf '%s\n' "$missing_steps" | /usr/bin/grep -q 'Developer ID Application certificate'
  printf '%s\n' "$missing_steps" | /usr/bin/grep -q 'Apple Development identity is not enough'
  printf '%s\n' "$missing_steps" | /usr/bin/grep -q 'TENKMRR_NOTARY_PROFILE'

  ready_steps="$(suggested_steps "true" "true" "false" "true")"
  printf '%s\n' "$ready_steps" | /usr/bin/grep -q './script/signing_preflight.sh --require-ready'
  printf '%s\n' "$ready_steps" | /usr/bin/grep -q './script/package_private_beta.sh --signed'

  if TENKMRR_NOTARY_PROFILE='private-profile-name' "$0" 2>/dev/null | /usr/bin/grep -q 'private-profile-name'; then
    printf 'Signing preflight self-test failed: notary profile name was printed.\n' >&2
    exit 1
  fi

  printf 'Signing preflight self-test passed.\n'
}

suggested_steps() {
  local has_notarytool="$1"
  local has_developer_id="$2"
  local has_apple_development="$3"
  local has_notary_profile="$4"

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

  if [[ "$has_notary_profile" != "true" ]]; then
    printf '  - Store notary credentials privately with xcrun notarytool store-credentials <profile-name>.\n'
    printf '  - Set TENKMRR_NOTARY_PROFILE to that keychain profile name before strict signing checks.\n'
  fi

  if [[ "$has_notarytool" == "true" && "$has_developer_id" == "true" && "$has_notary_profile" == "true" ]]; then
    printf '  - Re-run strict readiness: ./script/signing_preflight.sh --require-ready\n'
    printf '  - Then run a private signed/notarized package: ./script/package_private_beta.sh --signed\n'
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
has_notary_profile=false
notary_profile="${TENKMRR_NOTARY_PROFILE:-}"
notary_output="$(/usr/bin/mktemp -t 10kmrr-notary-profile.XXXXXX)"
trap 'rm -f "$notary_output"' EXIT

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

if [[ "$has_notarytool" == "true" ]]; then
  if [[ -z "$notary_profile" ]]; then
    printf 'WARN  TENKMRR_NOTARY_PROFILE is not set. Notary keychain profile readiness is not verified.\n'
    missing=1
  elif verify_notary_profile "$notary_profile" "$notary_output"; then
    printf 'PASS  Notary keychain profile is available.\n'
    has_notary_profile=true
  else
    printf 'WARN  Configured notary keychain profile could not be verified.\n'
    missing=1
  fi
else
  missing=1
fi

printf 'INFO  Notary credentials are not printed by this script. Store them privately with xcrun notarytool store-credentials <profile-name>.\n'
suggested_steps "$has_notarytool" "$has_developer_id" "$has_apple_development" "$has_notary_profile"

if [[ "$REQUIRE_READY" == "true" && "$missing" -ne 0 ]]; then
  exit 1
fi
