#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
EXECUTABLE="$BUILD_DIR/OverlaySettingsStoreTests"

mkdir -p "$BUILD_DIR"

/usr/bin/swiftc \
  -swift-version 5 \
  "$ROOT_DIR/MRRLockScreenOverlay/OverlaySettingOptions.swift" \
  "$ROOT_DIR/MRRLockScreenOverlay/OverlaySettingsStore.swift" \
  "$ROOT_DIR/tests/OverlaySettingsStoreTests.swift" \
  -o "$EXECUTABLE"

"$EXECUTABLE"
