#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MRRLockScreenOverlay"
APP_BUNDLE="$ROOT_DIR/build/LockScreenOverlay/$APP_NAME.app"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
PACKAGE_DIR="$ROOT_DIR/build/private-beta"
STAGE_DIR="$PACKAGE_DIR/stage"
ADHOC=false

usage() {
  cat <<EOF
Usage: $0 --adhoc

Builds a private, unnotarized beta zip under build/private-beta.

This does not create a public installer. The --adhoc flag is required so the
caller explicitly accepts that the package is ad-hoc signed, unnotarized, and
only suitable for internal/private alpha testing.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --adhoc)
      ADHOC=true
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

if [[ "$ADHOC" != "true" ]]; then
  usage >&2
  exit 64
fi

"$ROOT_DIR/script/verify_public_repo.sh"

commit="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || printf '0.0.0')"
package_name="10kmrr-life-$version-$commit-unnotarized-private-beta"
zip_path="$PACKAGE_DIR/$package_name.zip"
manifest_path="$PACKAGE_DIR/$package_name-manifest.txt"
sha_path="$PACKAGE_DIR/$package_name.sha256"

rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

/usr/bin/lipo "$EXECUTABLE" -verify_arch arm64 x86_64
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"

mkdir -p "$STAGE_DIR"
/usr/bin/ditto --norsrc --noextattr "$APP_BUNDLE" "$STAGE_DIR/$APP_NAME.app"
/usr/bin/find "$STAGE_DIR" \( -name '._*' -o -name '.DS_Store' \) -delete
/usr/bin/codesign --verify --deep --strict "$STAGE_DIR/$APP_NAME.app"

(
  cd "$STAGE_DIR"
  /usr/bin/zip -r -X -q "$zip_path" "$APP_NAME.app"
)

if /usr/bin/zipinfo -1 "$zip_path" | /usr/bin/grep -Eq '(^|/)\._|(^|/)\.DS_Store$'; then
  printf 'Package contains local metadata files. Refusing to continue.\n' >&2
  exit 1
fi

(
  cd "$PACKAGE_DIR"
  /usr/bin/shasum -a 256 "$(basename "$zip_path")" >"$sha_path"
)

cat >"$manifest_path" <<EOF
10kmrr.life private beta package

Package: $(basename "$zip_path")
Version: $version
Commit: $commit
Architecture: universal arm64 x86_64
Signing: ad-hoc
Notarized: no
Distribution: private alpha testing only

Safety boundary:
- Do not publish this zip as a public installer.
- Do not bundle Stripe keys.
- Do not share exact private MRR, raw Stripe responses, raw logs, customer data, payment data, or unsanitized screenshots.
- Use ./script/install_lock_overlay_agent.sh for LaunchAgent installation from source.
- Use ./script/uninstall_lock_overlay_agent.sh --all for a full local reset.

Verification:
- ./script/verify_public_repo.sh passed before packaging.
- codesign --verify --deep --strict passed.
- lipo verified arm64 and x86_64 slices.
EOF

printf 'Wrote private beta package artifacts:\n'
printf '  %s\n' "$zip_path"
printf '  %s\n' "$manifest_path"
printf '  %s\n' "$sha_path"
