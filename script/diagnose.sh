#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SUPPORT="$HOME/Library/Application Support/10kmrr.life"
BUILD_APP="$ROOT_DIR/build/LockScreenOverlay/MRRLockScreenOverlay.app"
BUILD_EXECUTABLE="$BUILD_APP/Contents/MacOS/MRRLockScreenOverlay"
INSTALLED_APP="$APP_SUPPORT/MRRLockScreenOverlay.app"
INSTALLED_EXECUTABLE="$INSTALLED_APP/Contents/MacOS/MRRLockScreenOverlay"
TARGET_PLIST="$HOME/Library/LaunchAgents/life.10kmrr.mrr-lock-overlay.plist"
LABEL="life.10kmrr.mrr-lock-overlay"
KEYCHAIN_SERVICE="life.10kmrr.MRRLockScreenOverlay"
LEGACY_KEYCHAIN_SERVICE="life.10kmrr.StripeMRRScreenSaver"
KEYCHAIN_ACCOUNT="stripe_api_key"
CACHE_DOMAIN="life.10kmrr.MRRLockScreenOverlay.Cache"
SETTINGS_DOMAIN="life.10kmrr.MRRLockScreenOverlay.Settings"
VERBOSE=false

case "${1:-}" in
  --verbose)
    VERBOSE=true
    ;;
  --help|-h)
    cat <<EOF
Usage: $0 [--verbose]

Checks local build, install, LaunchAgent, Keychain, and cache state without
printing the Stripe key or cached MRR value.
EOF
    exit 0
    ;;
  "")
    ;;
  *)
    printf 'Usage: %s [--verbose]\n' "$0" >&2
    exit 64
    ;;
esac

pass() {
  printf 'PASS  %s\n' "$1"
}

warn() {
  printf 'WARN  %s\n' "$1"
}

fail() {
  printf 'FAIL  %s\n' "$1"
}

exists_executable() {
  local path="$1"
  [[ -x "$path" ]]
}

bundle_value() {
  local app="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$app/Contents/Info.plist" 2>/dev/null || true
}

print_bundle_version() {
  local label="$1"
  local app="$2"
  local version build commit
  version="$(bundle_value "$app" "CFBundleShortVersionString")"
  build="$(bundle_value "$app" "CFBundleVersion")"
  commit="$(bundle_value "$app" "TenKMRRCommit")"
  printf '      %s version: %s' "$label" "${version:-unknown}"
  if [[ -n "$build" ]]; then
    printf ' build %s' "$build"
  fi
  if [[ -n "$commit" ]]; then
    printf ' commit %s' "$commit"
  fi
  printf '\n'
}

printf '10kmrr.life local diagnostic\n'
printf 'Repo: %s\n' "$ROOT_DIR"
printf 'Home: %s\n\n' "$HOME"

if exists_executable "$BUILD_EXECUTABLE"; then
  pass "Build artifact exists: $BUILD_APP"
  /usr/bin/file "$BUILD_EXECUTABLE" | /usr/bin/sed 's/^/      /'
  print_bundle_version "Build" "$BUILD_APP"
else
  warn "Build artifact missing. Run ./script/build_lock_overlay.sh --verify"
fi

if exists_executable "$INSTALLED_EXECUTABLE"; then
  pass "Installed app exists: $INSTALLED_APP"
  print_bundle_version "Installed" "$INSTALLED_APP"
else
  warn "Installed app missing. Run ./script/install_lock_overlay_agent.sh"
fi

if [[ -f "$TARGET_PLIST" ]]; then
  if /usr/bin/plutil -lint "$TARGET_PLIST" >/dev/null; then
    pass "LaunchAgent plist is valid: $TARGET_PLIST"
  else
    fail "LaunchAgent plist is invalid: $TARGET_PLIST"
  fi

  if /usr/bin/grep -q "$HOME" "$TARGET_PLIST"; then
    pass "LaunchAgent uses this user's HOME path."
  else
    warn "LaunchAgent does not appear to use this user's HOME path."
  fi
else
  warn "LaunchAgent plist missing: $TARGET_PLIST"
fi

launchctl_output="$(/usr/bin/mktemp -t 10kmrr-launchctl.XXXXXX)"
if /bin/launchctl print "gui/$(id -u)/$LABEL" >"$launchctl_output" 2>/dev/null; then
  pass "LaunchAgent is loaded."
  state="$(/usr/bin/awk -F'= ' '/state =/ { print $2; exit }' "$launchctl_output")"
  pid="$(/usr/bin/awk -F'= ' '/pid =/ { print $2; exit }' "$launchctl_output")"
  if [[ -n "${state:-}" ]]; then
    printf '      state: %s\n' "$state"
  fi
  if [[ -n "${pid:-}" ]]; then
    printf '      pid: %s\n' "$pid"
  fi
  if [[ "$VERBOSE" == "true" ]]; then
    /usr/bin/sed -n '1,45p' "$launchctl_output" | /usr/bin/sed 's/^/      /'
  fi
else
  warn "LaunchAgent is not loaded."
fi
rm -f "$launchctl_output"

if /usr/bin/security find-generic-password \
  -s "$KEYCHAIN_SERVICE" \
  -a "$KEYCHAIN_ACCOUNT" \
  >/dev/null 2>&1; then
  pass "Stripe key exists in Keychain. Key value was not printed."
elif /usr/bin/security find-generic-password \
  -s "$LEGACY_KEYCHAIN_SERVICE" \
  -a "$KEYCHAIN_ACCOUNT" \
  >/dev/null 2>&1; then
  warn "Stripe key exists under legacy Keychain service. The app will migrate it on next successful read."
else
  warn "Stripe key missing. Run ./script/build_lock_overlay.sh --setup"
fi

if /usr/bin/defaults read "$CACHE_DOMAIN" lastGoodMRR >/dev/null 2>&1; then
  pass "Last-good MRR cache exists. Cached value was not printed."
else
  warn "No last-good MRR cache yet."
fi

if /usr/bin/defaults read "$CACHE_DOMAIN" lastUpdated >/dev/null 2>&1; then
  pass "Last-updated timestamp exists."
else
  warn "No last-updated timestamp yet."
fi

refresh_interval="$({ /usr/bin/defaults read "$SETTINGS_DOMAIN" refreshIntervalSeconds 2>/dev/null || true; } | /usr/bin/head -1)"
placement="$({ /usr/bin/defaults read "$SETTINGS_DOMAIN" placement 2>/dev/null || true; } | /usr/bin/head -1)"
horizontal_placement="$({ /usr/bin/defaults read "$SETTINGS_DOMAIN" horizontalPlacement 2>/dev/null || true; } | /usr/bin/head -1)"
size_preset="$({ /usr/bin/defaults read "$SETTINGS_DOMAIN" sizePreset 2>/dev/null || true; } | /usr/bin/head -1)"
if [[ -n "$refresh_interval" && "$refresh_interval" =~ ^[0-9]+$ ]]; then
  pass "Refresh interval setting: $((refresh_interval / 60))m"
else
  pass "Refresh interval setting: default 5m"
fi
if [[ -n "$placement" ]]; then
  pass "Overlay position setting: $placement"
else
  pass "Overlay position setting: default center"
fi
if [[ -n "$horizontal_placement" ]]; then
  pass "Overlay horizontal setting: $horizontal_placement"
else
  pass "Overlay horizontal setting: default center"
fi
if [[ -n "$size_preset" ]]; then
  pass "Overlay size setting: $size_preset"
else
  pass "Overlay size setting: default medium"
fi

printf '\nSafe next steps:\n'
printf '  Configure key: ./script/build_lock_overlay.sh --setup\n'
printf '  Build verify:  ./script/build_lock_overlay.sh --verify\n'
printf '  Preview:       ./script/build_lock_overlay.sh --preview-private-glass\n'
printf '  Install:       ./script/install_lock_overlay_agent.sh\n'
printf '  Verbose diag:  ./script/diagnose.sh --verbose\n'
