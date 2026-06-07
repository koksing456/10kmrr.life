#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

section() {
  printf '\n==> %s\n' "$1"
}

section "Shell syntax"
while IFS= read -r script_path; do
  bash -n "$script_path"
done < <(find script -maxdepth 1 -type f -name '*.sh' | sort)

section "Executable script bits"
while IFS= read -r script_path; do
  if [[ ! -x "$script_path" ]]; then
    printf 'Expected script to be executable: %s\n' "$script_path" >&2
    exit 1
  fi
done < <(find script -maxdepth 1 -type f -name '*.sh' | sort)

section "Swift file size guard"
swift_line_limit=200
oversized_swift_files="$(
  /usr/bin/find MRRLockScreenOverlay -maxdepth 1 -type f -name '*.swift' -print0 |
    /usr/bin/xargs -0 /usr/bin/wc -l |
    /usr/bin/awk -v limit="$swift_line_limit" 'NF == 2 && $2 != "total" && $1 >= limit { print $1 " " $2 }'
)"
if [[ -n "$oversized_swift_files" ]]; then
  printf 'Swift files must stay under %s lines. Split these files before publishing:\n%s\n' "$swift_line_limit" "$oversized_swift_files" >&2
  exit 1
fi

section "Default settings consistency"
if ! rg -q 'fallback: \.hero' MRRLockScreenOverlay/OverlaySettingsStore.swift; then
  printf 'Expected OverlaySettingsStore visualStyle fallback to remain hero.\n' >&2
  exit 1
fi
if ! rg -q 'Overlay visual style setting: default hero' script/diagnose.sh; then
  printf 'Expected diagnose.sh to report the hero visual style default.\n' >&2
  exit 1
fi

section "MRR calculator tests"
./script/test_mrr_calculator.sh

section "MRR cache tests"
./script/test_mrr_cache.sh

section "Stripe client tests"
./script/test_stripe_client.sh

section "Overlay settings tests"
./script/test_overlay_settings.sh

section "Setup local support tests"
./script/test_setup_local_support.sh

section "Support report redaction"
./script/support_report.sh --self-test

section "Diagnostic command self-test"
./script/diagnose.sh --self-test

section "Stripe key validation"
./script/configure_stripe_key.sh --self-test

section "Installer plist generation"
./script/install_lock_overlay_agent.sh --self-test

section "Uninstall command self-test"
./script/uninstall_lock_overlay_agent.sh --self-test

section "Repair command self-test"
./script/repair_lock_overlay_agent.sh --self-test

section "Signing preflight parser"
./script/signing_preflight.sh --self-test

section "Private beta package manifest"
./script/package_private_beta.sh --self-test

section "Private beta readiness"
./script/private_beta_readiness.sh --self-test

section "GitHub label sync parser"
./script/sync_github_labels.sh --self-test

section "Alpha start flow"
./script/start_alpha.sh --self-test

section "Alpha CLI wrapper"
./script/alpha.sh --self-test

section "Alpha tracker generation"
./script/prepare_alpha_tracker.sh --self-test

section "Alpha tracker audit"
./script/audit_alpha_tracker.sh --self-test

section "Alpha invite generator"
./script/generate_alpha_invite.sh --self-test

section "Alpha tester approval wrapper"
./script/approve_alpha_tester.sh --self-test

section "Alpha invite packet wrapper"
./script/prepare_alpha_invite_packet.sh --self-test

section "Alpha install evidence recorder"
./script/record_alpha_install.sh --self-test

section "Alpha compatibility recorder"
./script/record_alpha_compatibility.sh --self-test

section "Alpha support issue recorder"
./script/record_alpha_support_issue.sh --self-test

section "Alpha success evidence wrapper"
./script/record_alpha_success.sh --self-test

section "Alpha Day 7 follow-up wrapper"
./script/record_alpha_day7.sh --self-test

section "Alpha local smoke recorder"
./script/record_alpha_local_smoke.sh --self-test

section "Local smoke runner"
./script/run_local_smoke.sh --self-test

section "Alpha user recorder"
./script/record_alpha_user.sh --self-test

section "Alpha Pro follow-up recorder"
./script/record_alpha_pro_followup.sh --self-test

section "Alpha weekly review recorder"
./script/record_alpha_weekly_review.sh --self-test

section "Alpha weekly summary"
./script/alpha_weekly_summary.sh --self-test

section "Alpha next action"
./script/alpha_next_action.sh --self-test

section "Alpha readiness report"
./script/alpha_readiness_report.sh --self-test

section "Alpha status summary"
./script/alpha_status.sh --self-test

section "Markdown local links"
./script/verify_markdown_links.sh

section "Static site syntax"
if ! command -v node >/dev/null 2>&1; then
  printf 'node is required to verify site/main.js syntax.\n' >&2
  exit 1
fi
node --check site/main.js

section "Static site server"
./script/serve_site.sh --self-test

section "Static site boundary"
test -s site/index.html
test -s site/styles.css
test -s site/main.js
require_site_phrase() {
  local pattern="$1"

  if ! rg -q "$pattern" site/index.html; then
    printf 'Expected static landing page wording missing: %s\n' "$pattern" >&2
    exit 1
  fi
}

require_site_phrase 'Private Mac alpha'
require_site_phrase 'Request private alpha'
require_site_phrase 'issues/new\?template=alpha_request\.yml'
require_site_phrase 'Mock demo'
require_site_phrase 'No alpha server stores your Stripe key or MRR'
require_site_phrase 'Restricted key'
require_site_phrase 'not a full analytics dashboard'
require_site_phrase 'No hosted Stripe key storage'
require_site_phrase 'Do not send Stripe keys, exact MRR, email/contact data'
require_site_phrase 'email/contact data'
require_site_phrase 'payment data'
require_site_phrase 'raw Stripe responses'
require_site_phrase 'raw logs'

if rg -ni '(download|public installer|buy now|start trial)' site/index.html; then
  printf 'Static landing page appears to imply public distribution or paid conversion before alpha readiness.\n' >&2
  exit 1
fi

section "macOS app build and signing"
./script/build_lock_overlay.sh --verify
/usr/bin/lipo build/LockScreenOverlay/MRRLockScreenOverlay.app/Contents/MacOS/MRRLockScreenOverlay -verify_arch arm64 x86_64

section "Demo asset presence"
test -s docs/demo/assets/landing-hero.png
test -s docs/demo/assets/landing-desktop.png
test -s docs/demo/assets/landing-mobile.png
test -s docs/demo/assets/social-square.png
test -s docs/demo/assets/social-wide.png
test -s docs/demo/assets/social-vertical.png
test -s docs/demo/assets/github-social-preview.png
test -s docs/demo/assets/demo-loop.mp4
test -s docs/demo/assets/demo-poster.png

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
local_scan_pattern="/Users/[[:alnum:]_.-]+|/var/folders|TemporaryItems|NSIRD|Screenshot 2026|MRRWallpaperUpdater|life\\.10kmrr\\.mrr-wallpaper"
local_matches="$(
  rg -n \
  "$local_scan_pattern" \
  . \
  -g '!build/**' \
  -g '!Atoll/**' \
  -g '!opc-doc/**' \
  -g '!.codex/**' \
  -g '!script/verify_public_repo.sh' |
    /usr/bin/grep -v '/Users/example' || true
)"
if [[ -n "$local_matches" ]]; then
  printf '%s\n' "$local_matches"
  printf 'Local-only path or retired wallpaper artifact found.\n' >&2
  exit 1
fi

section "Public ignore contract"
for ignored_path in build .codex opc-doc Atoll; do
  if ! /usr/bin/grep -qx "${ignored_path}/" .gitignore; then
    printf 'Expected .gitignore to contain %s/.\n' "$ignored_path" >&2
    exit 1
  fi
done

tracked_private_artifacts="$(
  git ls-files |
    rg '^(build|\.codex|opc-doc|Atoll|DerivedData)/|(^|/)\.DS_Store$|(^|/)xcuserdata/|\.xcuserstate$|\.log$|^\.env($|\.)' || true
)"
if [[ -n "$tracked_private_artifacts" ]]; then
  printf 'Private, local, or generated artifacts are tracked by git:\n%s\n' "$tracked_private_artifacts" >&2
  exit 1
fi

section "Public docs"
test -s README.md
test -s SECURITY.md
test -s PRIVACY.md
test -s CONTRIBUTING.md
test -s CODE_OF_CONDUCT.md
test -s CHANGELOG.md
test -s LICENSE
test -s .github/PULL_REQUEST_TEMPLATE.md
test -s .github/ISSUE_TEMPLATE/alpha_request.yml
test -s docs/alpha/free-pro-boundary.md
test -s docs/alpha/alpha-invite-template.md
test -s docs/alpha/alpha-ops-checklist.md
test -s docs/alpha/private-alpha-workflow.md
test -s docs/alpha/install-smoke-checklist.md
test -s docs/alpha/compatibility-matrix.md
test -s docs/alpha/support-playbook.md
test -s docs/alpha/testimonial-approval-template.md
test -s docs/alpha/improvement-backlog.md
test -s docs/alpha/templates/alpha-users.csv
test -s docs/alpha/templates/install-funnel.csv
test -s docs/alpha/templates/compatibility.csv
test -s docs/alpha/templates/local-smoke.csv
test -s docs/alpha/templates/pro-interest.csv
test -s docs/alpha/templates/weekly-review.csv
test -s docs/release/release-strategy.md
test -s docs/release/release-notes-template.md
test -s docs/release/private-beta-packaging-checklist.md

section "Public alpha wording gates"
require_phrase() {
  local file="$1"
  local pattern="$2"

  if ! rg -q "$pattern" "$file"; then
    printf 'Expected public-alpha wording missing from %s: %s\n' "$file" "$pattern" >&2
    exit 1
  fi
}

reject_phrase() {
  local file="$1"
  local pattern="$2"

  if rg -q "$pattern" "$file"; then
    printf 'Unsafe public-alpha wording found in %s: %s\n' "$file" "$pattern" >&2
    exit 1
  fi
}

section "Public operator command wording"
require_phrase README.md './script/alpha\.sh check'
require_phrase README.md './script/alpha\.sh support-report'
require_phrase README.md './script/alpha\.sh beta-ready'
require_phrase .github/PULL_REQUEST_TEMPLATE.md './script/alpha\.sh check'
require_phrase .github/ISSUE_TEMPLATE/alpha_feedback.md './script/alpha\.sh support-report'
require_phrase .github/ISSUE_TEMPLATE/alpha_feedback.md './script/alpha\.sh check'
require_phrase .github/ISSUE_TEMPLATE/bug_report.md './script/alpha\.sh support-report'
require_phrase .github/ISSUE_TEMPLATE/bug_report.md './script/alpha\.sh check'

require_phrase README.md 'gated alpha'
require_phrase README.md 'not a public installer'
require_phrase README.md 'private macOS behavior'
require_phrase README.md 'Do not use a full-access Stripe secret key'
require_phrase README.md 'There is no 10kmrr\.life server in the current alpha path'
require_phrase README.md 'mock MRR only'
require_phrase SECURITY.md 'restricted read-only Stripe API key'
require_phrase SECURITY.md 'Never send your Stripe key'
require_phrase SECURITY.md 'private macOS behavior'
require_phrase SECURITY.md 'not yet a notarized public release'
require_phrase SECURITY.md 'It does not include log excerpts by default'
require_phrase SECURITY.md 'the excerpts are still redacted'
require_phrase PRIVACY.md 'does not upload your Stripe key, MRR, customer data, payment data, or Stripe API responses'
require_phrase PRIVACY.md 'Do not include'
require_phrase PRIVACY.md 'not a notarized public Mac app yet'
require_phrase CODE_OF_CONDUCT.md 'Publishing or requesting Stripe API keys'
require_phrase CODE_OF_CONDUCT.md 'exact private MRR'
require_phrase CODE_OF_CONDUCT.md 'unsanitized screenshots'
require_phrase CODE_OF_CONDUCT.md 'hosted Stripe key storage or full analytics dashboard scope'
require_phrase docs/release/release-notes-template.md 'No Stripe keys are included'
require_phrase docs/release/release-notes-template.md 'No real MRR screenshots are included unless explicitly sanitized and approved'
require_phrase docs/release/release-notes-template.md 'not a public notarized installer'
require_phrase docs/alpha/alpha-request-template.md 'Keep name, handle, email, and preferred contact mapping outside this repo and outside public GitHub issues'
require_phrase docs/alpha/alpha-user-tracker.md 'Use stable tester ids such as `tester_001`'
require_phrase docs/alpha/install-smoke-checklist.md 'Do not record exact MRR'
require_phrase docs/alpha/seven-day-follow-up-template.md 'Do not record exact private MRR'
require_phrase docs/alpha/support-playbook.md 'the excerpts are still redacted'
require_phrase docs/demo/landing-skeleton.md 'Name, handle, email, or preferred contact in the public request flow'

for public_alpha_doc in README.md SECURITY.md docs/alpha/*.md .github/ISSUE_TEMPLATE/*.md; do
  reject_phrase "$public_alpha_doc" 'intentionally shares a sanitized value'
  reject_phrase "$public_alpha_doc" 'exact private MRR unless'
  reject_phrase "$public_alpha_doc" 'exact MRR unless'
done

section "GitHub issue safety wording"
for issue_template in .github/ISSUE_TEMPLATE/alpha_feedback.md .github/ISSUE_TEMPLATE/alpha_request.yml .github/ISSUE_TEMPLATE/bug_report.md; do
  require_phrase "$issue_template" 'Stripe keys'
  require_phrase "$issue_template" 'exact MRR'
  require_phrase "$issue_template" 'email/contact data'
  require_phrase "$issue_template" 'customer data'
  require_phrase "$issue_template" 'payment data'
  require_phrase "$issue_template" 'raw logs'
  require_phrase "$issue_template" 'unsanitized revenue screenshots'
done

section "GitHub label manifest"
for expected_label in alpha-request alpha-feedback bug compatibility install mrr-semantics security visual-design; do
  if ! rg -q "^- name: ${expected_label}$" .github/labels.yml; then
    printf 'Missing GitHub label in .github/labels.yml: %s\n' "$expected_label" >&2
    exit 1
  fi
done

declared_labels="$(/usr/bin/awk '/^- name: / { print $3 }' .github/labels.yml | /usr/bin/sort -u)"
used_issue_labels="$(
  {
    /usr/bin/awk '
      /^labels:[[:space:]]*[^[:space:]]/ {
        sub(/^labels:[[:space:]]*/, "")
        gsub(/"/, "")
        print
        next
      }
      /^labels:[[:space:]]*$/ {
        in_labels = 1
        next
      }
      in_labels && /^[[:space:]]*-[[:space:]]*/ {
        sub(/^[[:space:]]*-[[:space:]]*/, "")
        gsub(/"/, "")
        print
        next
      }
      in_labels && /^[^[:space:]-]/ {
        in_labels = 0
      }
    ' .github/ISSUE_TEMPLATE/*.yml

    /usr/bin/awk -F': ' '/^labels: / {
      gsub(/"/, "", $2)
      print $2
    }' .github/ISSUE_TEMPLATE/*.md
  } | /usr/bin/sort -u
)"

while IFS= read -r used_label; do
  [[ -z "$used_label" ]] && continue
  if ! printf '%s\n' "$declared_labels" | /usr/bin/grep -qx "$used_label"; then
    printf 'Issue template uses label missing from .github/labels.yml: %s\n' "$used_label" >&2
    exit 1
  fi
done <<< "$used_issue_labels"

printf '\nPublic repo verification passed.\n'
