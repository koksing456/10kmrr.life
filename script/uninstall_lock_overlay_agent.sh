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

usage() {
  cat <<EOF
Usage: $0 [--local-data] [--keychain] [--all] [--help]

Removes the Lock Screen overlay app and LaunchAgent.

Options:
  --local-data  Also remove local MRR cache and display settings.
  --keychain    Also remove the stored Stripe key from macOS Keychain.
  --all         Remove app, LaunchAgent, local cache/settings, and Keychain key.
  --help        Show this help.
EOF
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

launchctl bootout "gui/$(id -u)" "$TARGET_PLIST" 2>/dev/null || true
pkill -x MRRLockScreenOverlay 2>/dev/null || true
rm -f "$TARGET_PLIST"
rm -rf "$TARGET_APP"

printf 'Removed Lock Screen overlay LaunchAgent and app bundle.\n'

if [[ "$REMOVE_LOCAL_DATA" == "true" ]]; then
  /usr/bin/defaults delete "$CACHE_DOMAIN" 2>/dev/null || true
  /usr/bin/defaults delete "$SETTINGS_DOMAIN" 2>/dev/null || true
  printf 'Removed local MRR cache and display settings.\n'
fi

if [[ "$REMOVE_KEYCHAIN" == "true" ]]; then
  /usr/bin/security delete-generic-password \
    -s "$KEYCHAIN_SERVICE" \
    -a "$KEYCHAIN_ACCOUNT" \
    >/dev/null 2>&1 || true
  /usr/bin/security delete-generic-password \
    -s "$LEGACY_KEYCHAIN_SERVICE" \
    -a "$KEYCHAIN_ACCOUNT" \
    >/dev/null 2>&1 || true
  printf 'Removed Stripe key from macOS Keychain if it existed.\n'
fi
