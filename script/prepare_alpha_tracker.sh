#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="$ROOT_DIR/docs/alpha/templates"
OUTPUT_DIR="$ROOT_DIR/build/alpha-tracker"
SELF_TEST=false
FORCE=false

usage() {
  cat <<EOF
Usage: $0 [--output DIR] [--force] [--self-test] [--help]

Creates a private local alpha tracker workspace from the sanitized CSV
templates. The default output is build/alpha-tracker, which is ignored by git.

Options:
  --output DIR  Write tracker files to DIR instead of build/alpha-tracker.
  --force       Replace existing generated tracker files in the output dir.
  --self-test   Verify tracker generation in a temporary directory.
  --help        Show this help.
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
- retained day 7 yes/no/unknown
- Pro interest level
- blocker summary
- next action

Do not collect:

- Stripe API keys
- exact private MRR
- raw Stripe API responses
- customer, subscription, invoice, payment, email, or card data
- raw logs
- unsanitized screenshots

Suggested workflow:

1. Send docs/alpha/alpha-invite-template.md to approved testers.
2. Ask them to run ./script/start_alpha.sh.
3. Ask for ./script/support_report.sh only if something fails.
4. Record install attempts with ./script/record_alpha_install.sh.
5. Record only pass/warn/fail summaries and non-sensitive blockers.
6. Run the Day 7 follow-up from docs/alpha/seven-day-follow-up-template.md.

Example install evidence row:

./script/record_alpha_install.sh \\
  --tester-id tester_001 \\
  --stage installed \\
  --build-verify pass \\
  --configured-key yes \\
  --previewed yes \\
  --installed yes \\
  --saw-mrr yes \\
  --diagnose-summary "PASS summary only" \\
  --next-action "day 7 follow-up"
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

  /bin/cp "$TEMPLATE_DIR/$template_name" "$target"
  printf 'Wrote tracker file: %s\n' "$target"
}

validate_generated_tracker() {
  local output_dir="$1"
  local forbidden='(Stripe API keys|exact private MRR|raw Stripe API responses|customer, subscription, invoice, payment, email, or card data|unsanitized screenshots)'

  test -s "$output_dir/README.md"
  test -s "$output_dir/alpha-users.csv"
  test -s "$output_dir/install-funnel.csv"
  test -s "$output_dir/pro-interest.csv"
  test -s "$output_dir/weekly-review.csv"

  /usr/bin/head -1 "$output_dir/alpha-users.csv" | /usr/bin/grep -q 'tester_id,candidate,contact'
  /usr/bin/head -1 "$output_dir/install-funnel.csv" | /usr/bin/grep -q 'tester_id,attempt_date,stage'
  /usr/bin/head -1 "$output_dir/pro-interest.csv" | /usr/bin/grep -q 'tester_id,follow_up_date,retained_day_7'
  /usr/bin/head -1 "$output_dir/weekly-review.csv" | /usr/bin/grep -q 'week_start,support_load,setup_failure_rate'
  /usr/bin/grep -Eq "$forbidden" "$output_dir/README.md"

  if /usr/bin/grep -R -E '(sk_live_|sk_test_|rk_live_|rk_test_|whsec_)' "$output_dir" >/dev/null; then
    printf 'Generated alpha tracker contained a secret-like token.\n' >&2
    exit 1
  fi
}

generate_tracker() {
  local output_dir="$1"

  /bin/mkdir -p "$output_dir"
  write_readme "$output_dir"
  copy_template "alpha-users.csv" "$output_dir"
  copy_template "install-funnel.csv" "$output_dir"
  copy_template "pro-interest.csv" "$output_dir"
  copy_template "weekly-review.csv" "$output_dir"
  validate_generated_tracker "$output_dir"

  printf '\nPrivate alpha tracker ready: %s\n' "$output_dir"
  printf 'Keep this folder private. Do not commit tester tracker rows.\n'
}

self_test() {
  local temp_dir
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-alpha-tracker.XXXXXX)"
  trap 'rm -rf "$temp_dir"' RETURN

  OUTPUT_DIR="$temp_dir/tracker"
  FORCE=true
  generate_tracker "$OUTPUT_DIR" >/dev/null
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

generate_tracker "$OUTPUT_DIR"
