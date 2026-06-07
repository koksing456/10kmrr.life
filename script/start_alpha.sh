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

usage() {
  cat <<EOF
Usage: $0 [--dry-run] [--no-install] [--no-setup] [--no-preview] [--self-test] [--help]

Guides a gated alpha tester through the safe local first-run path:
  1. Build and verify the app.
  2. Open setup for restricted Stripe key storage in Keychain.
  3. Launch a mock MRR preview.
  4. Optionally install the LaunchAgent and run diagnose.

This script never asks for or prints a Stripe key. Enter the key only in the
macOS setup window.

Options:
  --dry-run     Print the steps without building, opening setup, previewing, or installing.
  --no-install Skip LaunchAgent install and final diagnose.
  --no-setup   Do not open the setup window.
  --no-preview Do not launch the mock preview.
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
5. ./script/install_lock_overlay_agent.sh
6. ./script/diagnose.sh

Sensitive-data rule: do not paste Stripe keys, exact private MRR, raw Stripe
responses, customer/payment data, raw logs, or unsanitized screenshots into
support channels.
EOF
}

self_test() {
  local output
  output="$("$0" --dry-run)"
  printf '%s\n' "$output" | /usr/bin/grep -q './script/build_lock_overlay.sh --verify'
  printf '%s\n' "$output" | /usr/bin/grep -q './script/install_lock_overlay_agent.sh'
  printf '%s\n' "$output" | /usr/bin/grep -q './script/diagnose.sh'
  printf '%s\n' "$output" | /usr/bin/grep -q 'do not paste Stripe keys'
  if printf '%s\n' "$output" | /usr/bin/grep -Eq '(sk_live_|sk_test_|rk_live_|rk_test_|whsec_)'; then
    printf 'start_alpha self-test failed: dry-run output contained a secret-like token.\n' >&2
    exit 1
  fi
  printf 'Alpha start flow self-test passed.\n'
}

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      INTERACTIVE=false
      ;;
    --no-install)
      INSTALL=false
      ;;
    --no-setup)
      OPEN_SETUP=false
      ;;
    --no-preview)
      PREVIEW_MOCK=false
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

section "Install LaunchAgent"
"$ROOT_DIR/script/install_lock_overlay_agent.sh"

section "Diagnose"
"$ROOT_DIR/script/diagnose.sh"

cat <<EOF

Alpha start complete.
Lock the Mac to verify the overlay on the Lock Screen.
If anything looks wrong, run ./script/support_report.sh and share only the
sanitized summary or failing section name.
EOF
