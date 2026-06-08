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
SOURCE_MARKER="$APP_SUPPORT/source-checkout.path"
KEYCHAIN_SERVICE="life.10kmrr.MRRLockScreenOverlay"
LEGACY_KEYCHAIN_SERVICE="life.10kmrr.StripeMRRScreenSaver"
KEYCHAIN_ACCOUNT="stripe_api_key"
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 [--self-test] [--help]

Builds and installs the Lock Screen overlay LaunchAgent for the current user.

Options:
  --self-test  Verify LaunchAgent plist generation without installing anything.
  --help       Show this help.
EOF
}

generate_launch_agent_plist() {
  local plist_path="$1"
  local executable_path="$2"
  local stdout_path="$3"
  local stderr_path="$4"

  rm -f "$plist_path"
  /usr/bin/plutil -create xml1 "$plist_path"
  /usr/bin/plutil -insert Label -string "life.10kmrr.mrr-lock-overlay" "$plist_path"
  /usr/bin/plutil -insert ProgramArguments -array "$plist_path"
  /usr/bin/plutil -insert ProgramArguments.0 -string "$executable_path" "$plist_path"
  /usr/bin/plutil -insert ProgramArguments.1 -string "--private-glass" "$plist_path"
  /usr/bin/plutil -insert RunAtLoad -bool YES "$plist_path"
  /usr/bin/plutil -insert KeepAlive -bool YES "$plist_path"
  /usr/bin/plutil -insert StandardOutPath -string "$stdout_path" "$plist_path"
  /usr/bin/plutil -insert StandardErrorPath -string "$stderr_path" "$plist_path"
  /usr/bin/plutil -lint "$plist_path" >/dev/null
}

write_source_marker() {
  local marker_path="$1"
  local source_root="$2"

  printf '%s\n' "$source_root" >"$marker_path"
  /bin/chmod 600 "$marker_path"
}

self_test_plist_generation() {
  local tmp_dir
  tmp_dir="$(mktemp -d -t 10kmrr-install-plist-test.XXXXXX)"

  local plist_path="$tmp_dir/life.10kmrr.mrr-lock-overlay.plist"
  local executable_path="$tmp_dir/Application Support/10kmrr.life/A&B/MRRLockScreenOverlay"
  local stdout_path="$tmp_dir/Application Support/10kmrr.life/logs/out.log"
  local stderr_path="$tmp_dir/Application Support/10kmrr.life/logs/err.log"

  generate_launch_agent_plist "$plist_path" "$executable_path" "$stdout_path" "$stderr_path"

  local generated_executable generated_argument generated_stdout generated_stderr
  generated_executable="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$plist_path")"
  generated_argument="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:1' "$plist_path")"
  generated_stdout="$(/usr/libexec/PlistBuddy -c 'Print :StandardOutPath' "$plist_path")"
  generated_stderr="$(/usr/libexec/PlistBuddy -c 'Print :StandardErrorPath' "$plist_path")"

  [[ "$generated_executable" == "$executable_path" ]]
  [[ "$generated_argument" == "--private-glass" ]]
  [[ "$generated_stdout" == "$stdout_path" ]]
  [[ "$generated_stderr" == "$stderr_path" ]]

  local marker_path="$tmp_dir/source-checkout.path"
  local marker_mode
  write_source_marker "$marker_path" "$tmp_dir/source checkout"
  [[ "$(<"$marker_path")" == "$tmp_dir/source checkout" ]]
  marker_mode="$(/usr/bin/stat -f '%Lp' "$marker_path")"
  [[ "$marker_mode" == "600" ]]

  rm -rf "$tmp_dir"
  printf 'Install LaunchAgent plist generation self-test passed.\n'
}

for arg in "$@"; do
  case "$arg" in
    --self-test)
      SELF_TEST=true
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

if [[ "$SELF_TEST" == "true" ]]; then
  self_test_plist_generation
  exit 0
fi

"$ROOT_DIR/script/build_lock_overlay.sh" --verify

mkdir -p "$APP_SUPPORT/logs" "$HOME/Library/LaunchAgents"
rm -rf "$TARGET_APP"
cp -R "$SOURCE_APP" "$TARGET_APP"
write_source_marker "$SOURCE_MARKER" "$ROOT_DIR"
generate_launch_agent_plist "$TARGET_PLIST" "$EXECUTABLE" "$OUT_LOG" "$ERR_LOG"

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
