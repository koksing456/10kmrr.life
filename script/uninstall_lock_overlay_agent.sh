#!/usr/bin/env bash
set -euo pipefail

TARGET_PLIST="$HOME/Library/LaunchAgents/life.10kmrr.mrr-lock-overlay.plist"
APP_SUPPORT="$HOME/Library/Application Support/10kmrr.life"
TARGET_APP="$APP_SUPPORT/MRRLockScreenOverlay.app"
KEYCHAIN_SERVICE="life.10kmrr.MRRLockScreenOverlay"
LEGACY_KEYCHAIN_SERVICE="life.10kmrr.StripeMRRScreenSaver"
KEYCHAIN_ACCOUNT="stripe_api_key"
CACHE_DOMAIN="life.10kmrr.MRRLockScreenOverlay.Cache"
SETTINGS_DOMAIN="life.10kmrr.MRRLockScreenOverlay.Settings"
REMOVE_LOCAL_DATA=false
REMOVE_KEYCHAIN=false
DRY_RUN=false

usage() {
  cat <<EOF
Usage: $0 [--local-data] [--keychain] [--all] [--dry-run] [--self-test] [--help]

Removes the Lock Screen overlay app and LaunchAgent.

Options:
  --local-data  Also remove local MRR cache and display settings.
  --keychain    Also remove the stored Stripe key from macOS Keychain.
  --all         Remove app, LaunchAgent, local cache/settings, and Keychain key.
  --dry-run     Print what would be removed without changing local state.
  --self-test   Validate uninstall option handling without changing local state.
  --help        Show this help.
EOF
}

run_action() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf 'DRY-RUN  %s\n' "$*"
  else
    "$@"
  fi
}

self_test() {
  local temp_home output
  temp_home="$(/usr/bin/mktemp -d -t 10kmrr-uninstall-home.XXXXXX)"
  trap 'rm -rf "$temp_home"' RETURN

  output="$(HOME="$temp_home" "$0" --dry-run --all 2>&1)"

  printf '%s\n' "$output" | /usr/bin/grep -q 'DRY-RUN  /bin/launchctl bootout'
  printf '%s\n' "$output" | /usr/bin/grep -q 'DRY-RUN  /usr/bin/pkill -x MRRLockScreenOverlay'
  printf '%s\n' "$output" | /usr/bin/grep -q "DRY-RUN  /bin/rm -f $temp_home/Library/LaunchAgents/life.10kmrr.mrr-lock-overlay.plist"
  printf '%s\n' "$output" | /usr/bin/grep -q "DRY-RUN  /bin/rm -rf $temp_home/Library/Application Support/10kmrr.life/MRRLockScreenOverlay.app"
  printf '%s\n' "$output" | /usr/bin/grep -q 'DRY-RUN  /usr/bin/defaults delete life.10kmrr.MRRLockScreenOverlay.Cache'
  printf '%s\n' "$output" | /usr/bin/grep -q 'DRY-RUN  /usr/bin/security delete-generic-password'
  printf '%s\n' "$output" | /usr/bin/grep -q 'Removed Stripe key from macOS Keychain if it existed.'

  printf 'uninstall self-test passed.\n'
}

for arg in "$@"; do
  case "$arg" in
    --local-data)
      REMOVE_LOCAL_DATA=true
      ;;
    --keychain)
      REMOVE_KEYCHAIN=true
      ;;
    --all)
      REMOVE_LOCAL_DATA=true
      REMOVE_KEYCHAIN=true
      ;;
    --dry-run)
      DRY_RUN=true
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

run_action /bin/launchctl bootout "gui/$(id -u)" "$TARGET_PLIST" 2>/dev/null || true
run_action /usr/bin/pkill -x MRRLockScreenOverlay 2>/dev/null || true
run_action /bin/rm -f "$TARGET_PLIST"
run_action /bin/rm -rf "$TARGET_APP"

printf 'Removed Lock Screen overlay LaunchAgent and app bundle.\n'

if [[ "$REMOVE_LOCAL_DATA" == "true" ]]; then
  run_action /usr/bin/defaults delete "$CACHE_DOMAIN" 2>/dev/null || true
  run_action /usr/bin/defaults delete "$SETTINGS_DOMAIN" 2>/dev/null || true
  printf 'Removed local MRR cache and display settings.\n'
fi

if [[ "$REMOVE_KEYCHAIN" == "true" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    run_action /usr/bin/security delete-generic-password \
      -s "$KEYCHAIN_SERVICE" \
      -a "$KEYCHAIN_ACCOUNT"
    run_action /usr/bin/security delete-generic-password \
      -s "$LEGACY_KEYCHAIN_SERVICE" \
      -a "$KEYCHAIN_ACCOUNT"
  else
    /usr/bin/security delete-generic-password \
      -s "$KEYCHAIN_SERVICE" \
      -a "$KEYCHAIN_ACCOUNT" \
      >/dev/null 2>&1 || true
    /usr/bin/security delete-generic-password \
      -s "$LEGACY_KEYCHAIN_SERVICE" \
      -a "$KEYCHAIN_ACCOUNT" \
      >/dev/null 2>&1 || true
  fi
  printf 'Removed Stripe key from macOS Keychain if it existed.\n'
fi
