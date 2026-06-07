#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/build/LockScreenOverlay/MRRLockScreenOverlay.app"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/MRRLockScreenOverlay"
PREVIEW_OUT_LOG="$ROOT_DIR/build/logs/mrr-lock-overlay-preview.out.log"
PREVIEW_ERR_LOG="$ROOT_DIR/build/logs/mrr-lock-overlay-preview.err.log"
INTERACTIVE=true
INSTALL=true
OPEN_SETUP=true
PREVIEW_MOCK=true
CHECK_READINESS=true
CACHE_DOMAIN="life.10kmrr.MRRLockScreenOverlay.Cache"
READINESS_TEST_MODE="${TENKMRR_START_ALPHA_READINESS_TEST_MODE:-}"
TESTER_ID=""

usage() {
  cat <<EOF
Usage: $0 [--tester-id ID] [--dry-run] [--no-install] [--no-setup] [--no-preview] [--skip-readiness-check] [--self-test] [--help]

Guides a gated alpha tester through the safe local first-run path:
  1. Build and verify the app.
  2. Open setup for restricted Stripe key storage in Keychain.
  3. Launch a mock MRR preview.
  4. Optionally install the LaunchAgent and run diagnose.
  5. Print the safe evidence-recording command after manual Lock Screen check.

This script never asks for or prints a Stripe key. Enter the key only in the
macOS setup window.

Options:
  --tester-id ID
                Stable private tester id. If provided, the final output includes
                a ready-to-run record_alpha_success.sh command.
  --dry-run     Print the steps without building, opening setup, previewing, or installing.
  --no-install Skip LaunchAgent install and final diagnose.
  --no-setup   Do not open the setup window.
  --no-preview Do not launch the mock preview.
  --skip-readiness-check
               Install without confirming Keychain key and last-good cache.
  --self-test  Verify command composition without changing local state.
  --help       Show this help.
EOF
}

section() {
  printf '\n==> %s\n' "$1"
}

dry_run_steps() {
  cat <<EOF
Alpha start flow:
1. ./script/build_lock_overlay.sh --verify
2. Open the verified app's setup window.
3. Launch the verified app's mock MRR preview.
4. Wait for the tester to save a restricted read-only Stripe key in setup.
5. Confirm Keychain key status and last-good MRR cache without printing values.
6. ./script/install_lock_overlay_agent.sh
7. ./script/diagnose.sh
8. After manually confirming Lock Screen visibility and unlock behavior, record
   success with ./script/record_alpha_success.sh.

Sensitive-data rule: do not paste Stripe keys, exact private MRR, raw Stripe
responses, customer/payment data, raw logs, or unsanitized screenshots into
support channels.
EOF
}

shell_quote() {
  local value="$1"
  printf "'%s'" "${value//\'/\'\\\'\'}"
}

detect_macos_version() {
  /usr/bin/sw_vers -productVersion 2>/dev/null || printf 'unknown'
}

detect_cpu_family() {
  case "$(/usr/bin/uname -m 2>/dev/null || true)" in
    arm64) printf 'apple_silicon' ;;
    x86_64) printf 'intel' ;;
    *) printf 'unknown' ;;
  esac
}

validate_tester_id() {
  local value="$1"

  if [[ -z "$value" ]]; then
    printf 'Missing value for --tester-id.\n' >&2
    exit 64
  fi

  if printf '%s\n' "$value" | /usr/bin/grep -Eq '[[:space:]]|[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+|([sr]k_(live|test)_|whsec_)|\b(cus|sub|price|prod|pi|ch|in|cs|pm|seti|si)_[A-Za-z0-9]{8,}\b|[Mm][Rr][Rr][[:space:]:=]+[0-9]'; then
    printf 'Unsafe --tester-id. Use a stable private id like tester_001, not contact data, secrets, Stripe ids, or revenue values.\n' >&2
    exit 64
  fi
}

print_success_record_command() {
  local macos_version cpu_family tester_arg
  macos_version="$(detect_macos_version)"
  cpu_family="$(detect_cpu_family)"

  cat <<EOF

After you manually confirm all three:
- MRR is visible.
- The overlay appears on the Lock Screen.
- The overlay hides after unlock.
EOF

  if [[ -n "$TESTER_ID" ]]; then
    tester_arg="$(shell_quote "$TESTER_ID")"
  else
    tester_arg="tester_XXX"
  fi

  cat <<EOF

Record the safe success evidence:
./script/record_alpha_success.sh \\
  --tester-id $tester_arg \\
  --macos-version $(shell_quote "$macos_version") \\
  --cpu $(shell_quote "$cpu_family") \\
  --display-setup built_in

Change --display-setup to external, multiple, or clamshell when that matches the tester machine.
EOF
}

self_test_cache() {
  local output
  output="$(TENKMRR_START_ALPHA_READINESS_TEST_MODE=missing confirm_ready_to_install 2>&1 || true)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Stripe key is not configured'
  printf '%s\n' "$output" | /usr/bin/grep -q 'Install paused before LaunchAgent changes'
}

self_test() {
  local output live_env
  live_env="live"
  output="$("$0" --dry-run)"
  printf '%s\n' "$output" | /usr/bin/grep -q './script/build_lock_overlay.sh --verify'
  printf '%s\n' "$output" | /usr/bin/grep -q './script/install_lock_overlay_agent.sh'
  printf '%s\n' "$output" | /usr/bin/grep -q './script/diagnose.sh'
  printf '%s\n' "$output" | /usr/bin/grep -q './script/record_alpha_success.sh'
  printf '%s\n' "$output" | /usr/bin/grep -q 'Confirm Keychain key status and last-good MRR cache'
  printf '%s\n' "$output" | /usr/bin/grep -q 'do not paste Stripe keys'
  output="$("$0" --dry-run --tester-id tester_001)"
  printf '%s\n' "$output" | /usr/bin/grep -q './script/record_alpha_success.sh'
  if "$0" --dry-run --tester-id 'founder@example.com' >/dev/null 2>&1; then
    printf 'start_alpha self-test failed: email-like tester id was accepted.\n' >&2
    exit 1
  fi
  if "$0" --dry-run --tester-id "rk_${live_env}_1234567890abcdef" >/dev/null 2>&1; then
    printf 'start_alpha self-test failed: secret-like tester id was accepted.\n' >&2
    exit 1
  fi
  if printf '%s\n' "$output" | /usr/bin/grep -Eq '(sk_live_|sk_test_|rk_live_|rk_test_|whsec_)'; then
    printf 'start_alpha self-test failed: dry-run output contained a secret-like token.\n' >&2
    exit 1
  fi
  self_test_cache
  printf 'Alpha start flow self-test passed.\n'
}

confirm_ready_to_install() {
  local ready=true
  local readiness_mode="${TENKMRR_START_ALPHA_READINESS_TEST_MODE:-$READINESS_TEST_MODE}"

  section "Confirm setup readiness"

  if [[ "$readiness_mode" == "missing" ]]; then
    printf 'WARN  Stripe key is not configured in Keychain.\n'
    ready=false
  elif "$ROOT_DIR/script/configure_stripe_key.sh" --status >/dev/null 2>&1; then
    printf 'PASS  Stripe key is configured in Keychain. Key value was not printed.\n'
  else
    printf 'WARN  Stripe key is not configured in Keychain.\n'
    ready=false
  fi

  if [[ "$readiness_mode" == "missing" ]]; then
    printf 'WARN  Last-good MRR cache is missing.\n'
    ready=false
  elif /usr/bin/defaults read "$CACHE_DOMAIN" lastGoodMRR >/dev/null 2>&1; then
    printf 'PASS  Last-good MRR cache exists. Cached value was not printed.\n'
  else
    printf 'WARN  Last-good MRR cache is missing.\n'
    ready=false
  fi

  if [[ "$readiness_mode" == "missing" ]]; then
    printf 'WARN  Last-updated timestamp is missing.\n'
    ready=false
  elif /usr/bin/defaults read "$CACHE_DOMAIN" lastUpdated >/dev/null 2>&1; then
    printf 'PASS  Last-updated timestamp exists.\n'
  else
    printf 'WARN  Last-updated timestamp is missing.\n'
    ready=false
  fi

  if [[ "$ready" != "true" ]]; then
    cat <<EOF

Install paused before LaunchAgent changes.
Finish setup first:
- Save a restricted read-only Stripe key in the setup window.
- Click Refresh MRR and confirm setup shows a successful local refresh.
- Run this script again, or run ./script/install_lock_overlay_agent.sh after setup is ready.

Use --skip-readiness-check only for mock-only or repair testing.
EOF
    return 70
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tester-id)
      if [[ $# -lt 2 || "${2:-}" == --* ]]; then
        usage >&2
        exit 64
      fi
      TESTER_ID="$2"
      validate_tester_id "$TESTER_ID"
      shift 2
      ;;
    --dry-run)
      INTERACTIVE=false
      shift
      ;;
    --no-install)
      INSTALL=false
      shift
      ;;
    --no-setup)
      OPEN_SETUP=false
      shift
      ;;
    --no-preview)
      PREVIEW_MOCK=false
      shift
      ;;
    --skip-readiness-check)
      CHECK_READINESS=false
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

cd "$ROOT_DIR"

if [[ "$INTERACTIVE" == "false" ]]; then
  dry_run_steps
  print_success_record_command
  exit 0
fi

section "Build and verify"
"$ROOT_DIR/script/build_lock_overlay.sh" --verify

if [[ "$OPEN_SETUP" == "true" ]]; then
  section "Open setup"
  /usr/bin/open -n "$APP_BUNDLE" --args --setup
  printf 'Opened setup window from verified app bundle.\n'
fi

if [[ "$PREVIEW_MOCK" == "true" ]]; then
  section "Launch mock preview"
  /usr/bin/pkill -f "$EXECUTABLE .*--preview" 2>/dev/null || true
  /bin/mkdir -p "$ROOT_DIR/build/logs"
  /usr/bin/nohup "$EXECUTABLE" --preview --private-glass --mock-mrr >"$PREVIEW_OUT_LOG" 2>"$PREVIEW_ERR_LOG" &
  sleep 3
  /usr/bin/pgrep -f "$EXECUTABLE .*--preview" >/dev/null
  printf 'Mock preview running. Stop it with: pkill -f "%s .*--preview"\n' "$EXECUTABLE"
fi

if [[ "$INSTALL" != "true" ]]; then
  printf '\nSkipped install. Run ./script/install_lock_overlay_agent.sh when setup is ready.\n'
  exit 0
fi

cat <<EOF

Finish setup in the macOS window before continuing:
- Preview mock MRR first.
- Save a restricted read-only Stripe key in Keychain.
- Click Refresh MRR and confirm the local cache updates.

Do not paste the Stripe key into Terminal or support messages.
EOF

printf '\nPress Return to install the Lock Screen LaunchAgent, or Ctrl-C to stop here. '
IFS= read -r _

if [[ "$CHECK_READINESS" == "true" ]]; then
  confirm_ready_to_install
fi

section "Install LaunchAgent"
"$ROOT_DIR/script/install_lock_overlay_agent.sh"

section "Diagnose"
"$ROOT_DIR/script/diagnose.sh"

cat <<EOF

Alpha start complete.
Lock the Mac to verify the overlay on the Lock Screen.
If anything looks wrong, run ./script/alpha.sh support-report and share only the
sanitized summary or failing section name.
EOF

print_success_record_command
