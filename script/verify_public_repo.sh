#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

section() {
  printf '\n==> %s\n' "$1"
}

section "Shell syntax"
bash -n \
  script/build_lock_overlay.sh \
  script/capture_demo_assets.sh \
  script/configure_stripe_key.sh \
  script/diagnose.sh \
  script/install_lock_overlay_agent.sh \
  script/open_setup.sh \
  script/serve_site.sh \
  script/test_mrr_calculator.sh \
  script/uninstall_lock_overlay_agent.sh \
  script/verify_public_repo.sh

section "MRR calculator tests"
./script/test_mrr_calculator.sh

section "macOS app build and signing"
./script/build_lock_overlay.sh --verify

section "Demo asset presence"
test -s docs/demo/assets/landing-hero.png
test -s docs/demo/assets/landing-desktop.png
test -s docs/demo/assets/landing-mobile.png

section "Secret scan"
if rg -n \
  "(sk_live_[A-Za-z0-9]+|sk_test_[A-Za-z0-9]+|rk_live_[A-Za-z0-9]+|rk_test_[A-Za-z0-9]+|whsec_[A-Za-z0-9]+)" \
  . \
  -g '!build/**' \
  -g '!Atoll/**' \
  -g '!opc-doc/**' \
  -g '!.codex/**' \
  -g '!script/verify_public_repo.sh'; then
  printf 'Potential Stripe secret found. Remove it before publishing.\n' >&2
  exit 1
fi

section "Local-only path and retired artifact scan"
user_path_pattern="/Users/${USER:-koksing}"
local_scan_pattern="${user_path_pattern}|/var/folders|TemporaryItems|NSIRD|Screenshot 2026|MRRWallpaperUpdater|life\\.10kmrr\\.mrr-wallpaper"
if rg -n \
  "$local_scan_pattern" \
  . \
  -g '!build/**' \
  -g '!Atoll/**' \
  -g '!opc-doc/**' \
  -g '!.codex/**' \
  -g '!script/verify_public_repo.sh'; then
  printf 'Local-only path or retired wallpaper artifact found.\n' >&2
  exit 1
fi

section "Public ignore contract"
for ignored_path in build .codex opc-doc Atoll; do
  if ! git check-ignore -q "$ignored_path"; then
    printf 'Expected %s to be ignored by git.\n' "$ignored_path" >&2
    exit 1
  fi
done

section "Public docs"
test -s README.md
test -s SECURITY.md
test -s LICENSE
test -s docs/alpha/free-pro-boundary.md
test -s docs/alpha/alpha-ops-checklist.md
test -s docs/alpha/install-smoke-checklist.md
test -s docs/alpha/compatibility-matrix.md
test -s docs/alpha/support-playbook.md
test -s docs/alpha/improvement-backlog.md
test -s docs/release/release-strategy.md

printf '\nPublic repo verification passed.\n'
