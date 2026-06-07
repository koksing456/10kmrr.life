#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tests"
EXECUTABLE="$BUILD_DIR/MRRCalculatorTests"
FIXTURE="$ROOT_DIR/tests/fixtures/mrr_calculator_cases.json"

mkdir -p "$BUILD_DIR"

/usr/bin/swiftc \
  -swift-version 5 \
  "$ROOT_DIR/MRRLockScreenOverlay/MRRModels.swift" \
  "$ROOT_DIR/MRRLockScreenOverlay/MRRCalculator.swift" \
  "$ROOT_DIR/tests/MRRCalculatorTests.swift" \
  -o "$EXECUTABLE"

"$EXECUTABLE" "$FIXTURE"
