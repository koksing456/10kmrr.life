#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SUPPORT="$HOME/Library/Application Support/10kmrr.life"
SOURCE_APP="$ROOT_DIR/build/LockScreenOverlay/MRRLockScreenOverlay.app"
TARGET_APP="$APP_SUPPORT/MRRLockScreenOverlay.app"
TARGET_PLIST="$HOME/Library/LaunchAgents/life.10kmrr.mrr-lock-overlay.plist"
EXECUTABLE="$TARGET_APP/Contents/MacOS/MRRLockScreenOverlay"
OUT_LOG="$APP_SUPPORT/logs/mrr-lock-overlay.out.log"
ERR_LOG="$APP_SUPPORT/logs/mrr-lock-overlay.err.log"
KEYCHAIN_SERVICE="life.10kmrr.MRRLockScreenOverlay"
LEGACY_KEYCHAIN_SERVICE="life.10kmrr.StripeMRRScreenSaver"
KEYCHAIN_ACCOUNT="stripe_api_key"

"$ROOT_DIR/script/build_lock_overlay.sh" --verify

mkdir -p "$APP_SUPPORT/logs" "$HOME/Library/LaunchAgents"
rm -rf "$TARGET_APP"
cp -R "$SOURCE_APP" "$TARGET_APP"
cat >"$TARGET_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>life.10kmrr.mrr-lock-overlay</string>
	<key>ProgramArguments</key>
	<array>
		<string>$EXECUTABLE</string>
		<string>--private-glass</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>$OUT_LOG</string>
	<key>StandardErrorPath</key>
	<string>$ERR_LOG</string>
</dict>
</plist>
EOF
/usr/bin/plutil -lint "$TARGET_PLIST" >/dev/null

launchctl bootout "gui/$(id -u)" "$TARGET_PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$TARGET_PLIST"
launchctl kickstart -k "gui/$(id -u)/life.10kmrr.mrr-lock-overlay"
sleep 2
launchctl_output="$(/usr/bin/mktemp -t 10kmrr-install-launchctl.XXXXXX)"
if launchctl print "gui/$(id -u)/life.10kmrr.mrr-lock-overlay" >"$launchctl_output" 2>/dev/null; then
  state="$(/usr/bin/awk -F'= ' '/state =/ { print $2; exit }' "$launchctl_output")"
  pid="$(/usr/bin/awk -F'= ' '/pid =/ { print $2; exit }' "$launchctl_output")"
  printf 'LaunchAgent loaded'
  if [[ -n "${state:-}" ]]; then
    printf ' (state: %s' "$state"
    if [[ -n "${pid:-}" ]]; then
      printf ', pid: %s' "$pid"
    fi
    printf ')'
  fi
  printf '.\n'
else
  printf 'Warning: LaunchAgent did not report as loaded. Run ./script/diagnose.sh.\n' >&2
fi
rm -f "$launchctl_output"

if ! /usr/bin/security find-generic-password \
  -s "$KEYCHAIN_SERVICE" \
  -a "$KEYCHAIN_ACCOUNT" \
  >/dev/null 2>&1 && \
  ! /usr/bin/security find-generic-password \
    -s "$LEGACY_KEYCHAIN_SERVICE" \
    -a "$KEYCHAIN_ACCOUNT" \
    >/dev/null 2>&1; then
  printf 'Warning: Stripe key is not configured. Opening setup window.\n' >&2
  /usr/bin/open -n "$TARGET_APP" --args --setup
fi

printf 'Installed overlay app: %s\n' "$TARGET_APP"
printf 'Installed LaunchAgent: %s\n' "$TARGET_PLIST"
