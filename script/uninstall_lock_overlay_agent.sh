#!/usr/bin/env bash
set -euo pipefail

TARGET_PLIST="$HOME/Library/LaunchAgents/life.10kmrr.mrr-lock-overlay.plist"
TARGET_APP="$HOME/Library/Application Support/10kmrr.life/MRRLockScreenOverlay.app"

launchctl bootout "gui/$(id -u)" "$TARGET_PLIST" 2>/dev/null || true
pkill -x MRRLockScreenOverlay 2>/dev/null || true
rm -f "$TARGET_PLIST"
rm -rf "$TARGET_APP"

printf 'Removed Lock Screen overlay LaunchAgent and app bundle.\n'
