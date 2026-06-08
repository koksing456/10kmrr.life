#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="$ROOT_DIR/docs/alpha/templates"
OUTPUT_DIR="$ROOT_DIR/build/alpha-tracker"
SELF_TEST=false
FORCE=false
README_ONLY=false
TRACKER_TEMPLATES=(
  "alpha-users.csv"
  "install-funnel.csv"
  "compatibility.csv"
  "local-smoke.csv"
  "pro-interest.csv"
  "weekly-review.csv"
)

usage() {
  cat <<EOF
Usage: $0 [--output DIR] [--force] [--readme-only] [--self-test] [--help]

Creates a private local alpha tracker workspace from the sanitized CSV
templates. The default output is build/alpha-tracker, which is ignored by git.

Options:
  --output DIR   Write tracker files to DIR instead of build/alpha-tracker.
  --force        Replace empty generated tracker files; refuses private rows.
  --readme-only  Refresh only README.md without replacing tracker CSV files.
  --self-test    Verify tracker generation in a temporary directory.
  --help         Show this help.
EOF
}

write_readme() {
  local output_dir="$1"

  cat >"$output_dir/README.md" <<EOF
# 10kmrr.life Private Alpha Tracker

This folder is for private alpha operations. Keep it out of the public repo.

Track only non-sensitive fields:

- install status
- macOS version
- CPU family
- display setup
- restricted key setup status
- first MRR seen yes/no
- Lock Screen compatibility pass/warn/fail
- local release-smoke pass/warn/fail
- retained day 7 yes/no/unknown
- Pro interest level
- blocker summary
- next action

Use stable tester ids such as tester_001. Keep identity and contact mapping outside this repo.

Do not collect:

- Stripe API keys
- Stripe object IDs
- exact private MRR
- raw Stripe API responses
- customer, subscription, invoice, payment, email, or card data
- raw logs
- personal contact details
- unsanitized screenshots

Suggested workflow:

1. Start with ./script/alpha.sh next for the single recommended safe action.
2. Write a local readiness report with ./script/alpha.sh report when you need a shareable private status packet.
3. Prepare the approved tester invite packet with ./script/alpha.sh invite.
4. Send the generated invite body from build/alpha-invites/tester_001.md.
5. Ask them to run ./script/alpha.sh start --tester-id tester_001.
6. Ask for ./script/alpha.sh health first if something fails.
7. Ask for ./script/alpha.sh support-report only if a sanitized shareable report is needed.
8. Record common support issues with ./script/alpha.sh support.
9. Record install attempts with ./script/alpha.sh install when you need custom partial evidence.
10. Record Lock Screen compatibility with ./script/alpha.sh compatibility.
   For a successful tester, run the alpha.sh success command printed by start.
11. Preview private beta local smoke with ./script/alpha.sh smoke.
12. Record private beta local smoke on a clean smoke machine with ./script/alpha.sh smoke --apply --full-reset --confirm-full-reset --record.
13. Record Day 7 / Pro signal with ./script/alpha.sh day7.
14. Review weekly safe aggregates with ./script/alpha.sh weekly.
15. Audit private tracker safety with ./script/alpha.sh audit.
16. Record weekly aggregate review with ./script/alpha.sh review.
17. Record only pass/warn/fail summaries and non-sensitive blockers.

Example approved tester and install evidence rows:

./script/alpha.sh next

./script/alpha.sh report

./script/alpha.sh invite \\
  --tester-id tester_001 \\
  --uses-stripe-subscriptions yes \\
  --macos-version 15.5 \\
  --cpu apple_silicon \\
  --display-setup built_in

./script/alpha.sh support \\
  --tester-id tester_001 \\
  --issue-type lock_screen \\
  --result fail \\
  --macos-version 15.5 \\
  --cpu apple_silicon \\
  --display-setup built_in \\
  --blocker "Lock Screen panel did not appear" \\
  --next-action "repair then retry diagnose"

./script/alpha.sh install \\
  --tester-id tester_001 \\
  --stage installed \\
  --build-verify pass \\
  --configured-key yes \\
  --previewed yes \\
  --installed yes \\
  --saw-mrr yes \\
  --diagnose-summary "PASS summary only" \\
  --next-action "day 7 follow-up"

./script/alpha.sh compatibility \\
  --tester-id tester_001 \\
  --macos-version 15.5 \\
  --cpu apple_silicon \\
  --display-setup built_in \\
  --build-verify pass \\
  --preview-glass private \\
  --lock-screen-visible yes \\
  --unlock-hides-overlay yes \\
  --launchagent-stable yes \\
  --result pass \\
  --next-action "day 7 follow-up"

Successful tester shortcut:

./script/alpha.sh success \\
  --tester-id tester_001 \\
  --macos-version 15.5 \\
  --cpu apple_silicon \\
  --display-setup built_in

./script/alpha.sh smoke

./script/alpha.sh smoke --apply --full-reset --confirm-full-reset --record

./script/alpha.sh day7 \\
  --tester-id tester_001 \\
  --retained-day-7 yes \\
  --signed-notarized-installer 3 \\
  --compatibility-updates 2 \\
  --overall-pro-signal medium \\
  --notes "kept it on for day 7"

./script/alpha.sh weekly

./script/alpha.sh audit

./script/alpha.sh review \\
  --week-start 2026-06-08 \\
  --support-load low \\
  --setup-failure-rate low \\
  --retention-count 2 \\
  --pro-signal-count 1 \\
  --compatibility-failures 0 \\
  --decision continue \\
  --next-action "invite next tester"
EOF
}

copy_template() {
  local template_name="$1"
  local output_dir="$2"
  local target="$output_dir/$template_name"

  if [[ -f "$target" && "$FORCE" != "true" ]]; then
    printf 'Keeping existing tracker file: %s\n' "$target"
    return
  fi

  if [[ -f "$target" && "$FORCE" == "true" ]] && tracker_file_has_private_rows "$target" "$TEMPLATE_DIR/$template_name"; then
    printf 'Refusing to replace tracker file with existing private rows: %s\n' "$target" >&2
    printf 'Move or back up that file first, then rerun with --force.\n' >&2
    return 1
  fi

  /bin/cp "$TEMPLATE_DIR/$template_name" "$target"
  printf 'Wrote tracker file: %s\n' "$target"
}

tracker_file_has_private_rows() {
  local target="$1"
  local template="$2"
  local template_example=""

  if [[ -f "$template" ]]; then
    template_example="$(/usr/bin/sed -n '2p' "$template")"
  fi

  /usr/bin/awk -v template_example="$template_example" '
    NR > 1 && length($0) > 0 && $0 != template_example { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$target"
}

preflight_force_replace() {
  local output_dir="$1"
  local template_name target

  [[ "$FORCE" == "true" ]] || return 0

  for template_name in "${TRACKER_TEMPLATES[@]}"; do
    target="$output_dir/$template_name"
    if [[ -f "$target" ]] && tracker_file_has_private_rows "$target" "$TEMPLATE_DIR/$template_name"; then
      printf 'Refusing --force because tracker file has existing private rows: %s\n' "$target" >&2
      printf 'Move or back up that file first, then rerun with --force.\n' >&2
      return 1
    fi
  done
}

validate_tracker_readme() {
  local output_dir="$1"
  local forbidden='(Stripe API keys|Stripe object IDs|exact private MRR|raw Stripe API responses|customer, subscription, invoice, payment, email, or card data|unsanitized screenshots)'

  test -s "$output_dir/README.md"
  /usr/bin/grep -Eq "$forbidden" "$output_dir/README.md"
  /usr/bin/grep -q 'Keep identity and contact mapping outside this repo' "$output_dir/README.md"
  /usr/bin/grep -q './script/alpha.sh next' "$output_dir/README.md"
  /usr/bin/grep -q './script/alpha.sh report' "$output_dir/README.md"
  /usr/bin/grep -q './script/alpha.sh invite' "$output_dir/README.md"
  /usr/bin/grep -q './script/alpha.sh support' "$output_dir/README.md"
  /usr/bin/grep -q './script/alpha.sh audit' "$output_dir/README.md"
  /usr/bin/grep -q './script/alpha.sh smoke --apply --full-reset --confirm-full-reset --record' "$output_dir/README.md"
  /usr/bin/grep -q './script/alpha.sh day7' "$output_dir/README.md"
  /usr/bin/grep -q './script/alpha.sh weekly' "$output_dir/README.md"
}

validate_generated_tracker() {
  local output_dir="$1"

  validate_tracker_readme "$output_dir"
  test -s "$output_dir/alpha-users.csv"
  test -s "$output_dir/install-funnel.csv"
  test -s "$output_dir/compatibility.csv"
  test -s "$output_dir/local-smoke.csv"
  test -s "$output_dir/pro-interest.csv"
  test -s "$output_dir/weekly-review.csv"

  /usr/bin/head -1 "$output_dir/alpha-users.csv" | /usr/bin/grep -q 'tester_id,uses_stripe_subscriptions,macos_version'
  /usr/bin/head -1 "$output_dir/install-funnel.csv" | /usr/bin/grep -q 'tester_id,attempt_date,stage'
  /usr/bin/head -1 "$output_dir/compatibility.csv" | /usr/bin/grep -q 'tester_id,check_date,macos_version'
  /usr/bin/head -1 "$output_dir/local-smoke.csv" | /usr/bin/grep -q 'smoke_date,build_verify,install_agent'
  /usr/bin/head -1 "$output_dir/pro-interest.csv" | /usr/bin/grep -q 'tester_id,follow_up_date,retained_day_7'
  /usr/bin/head -1 "$output_dir/weekly-review.csv" | /usr/bin/grep -q 'week_start,support_load,setup_failure_rate'

  if /usr/bin/grep -R -E '(sk_live_|sk_test_|rk_live_|rk_test_|whsec_)' "$output_dir" >/dev/null; then
    printf 'Generated alpha tracker contained a secret-like token.\n' >&2
    exit 1
  fi
}

generate_tracker() {
  local output_dir="$1"
  local template_name

  /bin/mkdir -p "$output_dir"
  if ! preflight_force_replace "$output_dir"; then
    return 1
  fi
  write_readme "$output_dir"
  for template_name in "${TRACKER_TEMPLATES[@]}"; do
    copy_template "$template_name" "$output_dir"
  done
  validate_generated_tracker "$output_dir"

  printf '\nPrivate alpha tracker ready: %s\n' "$output_dir"
  printf 'Keep this folder private. Do not commit tester tracker rows.\n'
}

refresh_readme_only() {
  local output_dir="$1"

  /bin/mkdir -p "$output_dir"
  write_readme "$output_dir"
  validate_tracker_readme "$output_dir"

  printf '\nPrivate alpha tracker README refreshed: %s\n' "$output_dir/README.md"
  printf 'Tracker CSV files were not replaced.\n'
}

self_test() {
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-alpha-tracker.XXXXXX)"
  trap 'rm -rf "$temp_dir"' RETURN

  OUTPUT_DIR="$temp_dir/tracker"
  FORCE=true
  generate_tracker "$OUTPUT_DIR" >/dev/null
  printf 'tester_selftest,2026-06-08,installed,pass,yes,yes,yes,yes,"sentinel row","none","keep"\n' >>"$OUTPUT_DIR/install-funnel.csv"
  README_ONLY=true
  refresh_readme_only "$OUTPUT_DIR" >/dev/null
  /usr/bin/grep -q 'tester_selftest' "$OUTPUT_DIR/install-funnel.csv"
  README_ONLY=false
  if generate_tracker "$OUTPUT_DIR" >/dev/null 2>&1; then
    printf 'Alpha tracker self-test failed: --force replaced a tracker with private rows.\n' >&2
    exit 1
  fi
  printf 'Alpha tracker generation self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      if [[ $# -lt 2 ]]; then
        usage >&2
        exit 64
      fi
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --readme-only)
      README_ONLY=true
      shift
      ;;
    --self-test)
      SELF_TEST=true
      shift
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
  self_test
  exit 0
fi

if [[ "$README_ONLY" == "true" ]]; then
  refresh_readme_only "$OUTPUT_DIR"
  exit 0
fi

generate_tracker "$OUTPUT_DIR"
