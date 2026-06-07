#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MRRLockScreenOverlay"
SOURCE="$ROOT_DIR/MRRLockScreenOverlay/MRRLockScreenOverlay.swift"
INFO_PLIST="$ROOT_DIR/MRRLockScreenOverlay/Info.plist"
BUILD_DIR="$ROOT_DIR/build/LockScreenOverlay"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

build_app() {
  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$ROOT_DIR/build/logs"
  cp "$INFO_PLIST" "$APP_BUNDLE/Contents/Info.plist"
  /usr/bin/swiftc \
    -swift-version 5 \
    -target arm64-apple-macos14.0 \
    -O \
    -framework AppKit \
    -framework SwiftUI \
    -framework Security \
    -framework CoreGraphics \
    -framework CoreFoundation \
    "$SOURCE" \
    -o "$EXECUTABLE"
  /usr/bin/codesign --force --sign - --timestamp=none "$APP_BUNDLE" >/dev/null
  printf 'Built %s\n' "$APP_BUNDLE"
}

verify_app() {
  test -d "$APP_BUNDLE"
  test -x "$EXECUTABLE"
  /usr/bin/plutil -p "$APP_BUNDLE/Contents/Info.plist" | /usr/bin/grep -q 'MRRLockScreenOverlay'
  /usr/bin/file "$EXECUTABLE"
  /usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
  /usr/bin/codesign -dv "$APP_BUNDLE" 2>&1 | /usr/bin/sed -n '1,8p'
}

preview_app() {
  local extra_arg="${1:-}"
  /usr/bin/pkill -f "$EXECUTABLE .*--preview" 2>/dev/null || true
  if [[ -n "$extra_arg" ]]; then
    /usr/bin/nohup "$EXECUTABLE" --preview "$extra_arg" >"$ROOT_DIR/build/logs/mrr-lock-overlay-preview.out.log" 2>"$ROOT_DIR/build/logs/mrr-lock-overlay-preview.err.log" &
  else
    /usr/bin/nohup "$EXECUTABLE" --preview >"$ROOT_DIR/build/logs/mrr-lock-overlay-preview.out.log" 2>"$ROOT_DIR/build/logs/mrr-lock-overlay-preview.err.log" &
  fi
  sleep 3
  /usr/bin/pgrep -f "$EXECUTABLE .*--preview" >/dev/null
  printf 'Preview running. Stop it with: pkill -f "%s .*--preview"\n' "$EXECUTABLE"
  printf 'LaunchAgent remains loaded while preview is running.\n'
}

logs() {
  /usr/bin/log stream --info --style compact --predicate 'process == "MRRLockScreenOverlay"'
}

open_setup() {
  build_app
  verify_app
  /usr/bin/open -n "$APP_BUNDLE" --args --setup
  printf 'Opened 10kmrr.life setup window.\n'
}

case "${1:-}" in
  --verify)
    build_app
    verify_app
    ;;
  --setup)
    open_setup
    ;;
  --preview)
    build_app
    preview_app
    ;;
  --preview-private-glass)
    build_app
    preview_app "--private-glass"
    ;;
  --logs)
    logs
    ;;
  "")
    build_app
    ;;
  *)
    printf 'Usage: %s [--verify|--setup|--preview|--preview-private-glass|--logs]\n' "$0" >&2
    exit 64
    ;;
esac
