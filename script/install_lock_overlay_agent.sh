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
launchctl print "gui/$(id -u)/life.10kmrr.mrr-lock-overlay" | /usr/bin/sed -n '1,80p'

if ! /usr/bin/security find-generic-password \
  -s "life.10kmrr.StripeMRRScreenSaver" \
  -a "stripe_api_key" \
  >/dev/null 2>&1; then
  printf 'Warning: Stripe key is not configured. Run ./script/configure_stripe_key.sh before expecting live MRR.\n' >&2
fi

printf 'Installed overlay app: %s\n' "$TARGET_APP"
printf 'Installed LaunchAgent: %s\n' "$TARGET_PLIST"
