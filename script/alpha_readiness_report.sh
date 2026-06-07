#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
OUTPUT_FILE="$ROOT_DIR/build/alpha-readiness-report.md"
SELF_TEST=false
PRINT_STDOUT=false

usage() {
  cat <<EOF
Usage: $0 [--tracker-dir DIR] [--output FILE] [--stdout] [--self-test] [--help]

Writes a safe private alpha readiness report. The report is intended for local
operator review and uses only aggregate/sanitized command output.

Options:
  --tracker-dir DIR  Tracker directory. Default: build/alpha-tracker.
  --output FILE      Output report path. Default: build/alpha-readiness-report.md.
  --stdout           Also print the report after writing it.
  --self-test        Verify report generation and safety scanning.
  --help             Show this help.
EOF
}

require_arg() {
  local option="$1"
  if [[ $# -lt 2 || "${2:-}" == --* ]]; then
    printf 'Missing value for %s.\n' "$option" >&2
    exit 64
  fi
}

shell_join() {
  local first=true part
  for part in "$@"; do
    if [[ "$first" == "true" ]]; then
      first=false
    else
      printf ' '
    fi
    printf '%q' "$part"
  done
}

display_shell_join() {
  local first=true part display_part
  for part in "$@"; do
    display_part="$part"
    if [[ "$display_part" == "$ROOT_DIR/"* ]]; then
      display_part="./${display_part#"$ROOT_DIR/"}"
    elif [[ "$display_part" == "$TRACKER_DIR" ]]; then
      display_part="build/alpha-tracker"
    fi

    if [[ "$first" == "true" ]]; then
      first=false
    else
      printf ' '
    fi
    printf '%q' "$display_part"
  done
}

append_command_section() {
  local output_file="$1"
  local title="$2"
  shift 2
  local command_output display_command status=0
  display_command="$(display_shell_join "$@")"

  {
    printf '## %s\n\n' "$title"
    printf 'Command: `%s`\n\n' "$display_command"
    printf '```text\n'
  } >>"$output_file"

  set +e
  command_output="$("$@" 2>&1)"
  status=$?
  set -e

  {
    printf '%s\n' "$command_output"
    printf '```\n\n'
    printf 'Exit status: `%s`\n\n' "$status"
  } >>"$output_file"
}

assert_report_safe() {
  local file="$1"

  if /usr/bin/grep -Eq '(sk_live_|sk_test_|rk_live_|rk_test_|whsec_)' "$file"; then
    printf 'Readiness report contains a secret-like token: %s\n' "$file" >&2
    return 1
  fi

  if /usr/bin/grep -Eq '[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+' "$file"; then
    printf 'Readiness report contains email-like contact data: %s\n' "$file" >&2
    return 1
  fi

  if /usr/bin/grep -Eq '\b(cus|sub|price|prod|pi|ch|in|cs|pm|seti|si)_[A-Za-z0-9]{8,}\b|client_secret|hosted_invoice_url|invoice_pdf|payment_method|customer_email' "$file"; then
    printf 'Readiness report contains Stripe object or raw Stripe field: %s\n' "$file" >&2
    return 1
  fi

  if /usr/bin/grep -Eq '([A-Z]{2,4}\$[0-9][0-9,]*(\.[0-9]{2})?|[A-Z]{3}[[:space:]]+[0-9][0-9,]*(\.[0-9]{2})?|\$[0-9][0-9,]*(\.[0-9]{2})?|([Rr]evenue|[Aa]mount)[[:space:]:=]+[0-9][0-9,]*(\.[0-9]{2})?)' "$file"; then
    printf 'Readiness report contains obvious private money amount: %s\n' "$file" >&2
    return 1
  fi
}

write_report() {
  local output_file="$1"
  local temp_file commit branch generated_at

  /bin/mkdir -p "$(dirname "$output_file")"
  temp_file="$(/usr/bin/mktemp -t 10kmrr-alpha-readiness.XXXXXX)"
  commit="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
  branch="$(git -C "$ROOT_DIR" branch --show-current 2>/dev/null || printf 'unknown')"
  generated_at="$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"

  {
    printf '# 10kmrr.life Alpha Readiness Report\n\n'
    printf '%s\n' "- Generated: \`$generated_at\`"
    printf '%s\n' "- Branch: \`$branch\`"
    printf '%s\n' "- Commit: \`$commit\`"
    printf '%s\n\n' "- Scope: private alpha readiness; not a public installer decision."
    printf 'Safety boundary: do not collect Stripe keys, exact MRR, raw logs, raw Stripe responses, customer/payment data, contact data, or unsanitized screenshots.\n\n'
  } >"$temp_file"

  append_command_section "$temp_file" "Single Recommended Action" "$ROOT_DIR/script/alpha_next_action.sh" --tracker-dir "$TRACKER_DIR"
  append_command_section "$temp_file" "Private Tracker Audit" "$ROOT_DIR/script/audit_alpha_tracker.sh" --tracker-dir "$TRACKER_DIR"
  append_command_section "$temp_file" "Weekly Alpha Summary" "$ROOT_DIR/script/alpha_weekly_summary.sh" --tracker-dir "$TRACKER_DIR"
  append_command_section "$temp_file" "Private Beta Readiness" "$ROOT_DIR/script/private_beta_readiness.sh" --tracker-dir "$TRACKER_DIR" --exclude-intel

  assert_report_safe "$temp_file"
  /bin/mv "$temp_file" "$output_file"

  printf 'Wrote safe alpha readiness report: %s\n' "$output_file"
  if [[ "$PRINT_STDOUT" == "true" ]]; then
    printf '\n'
    /bin/cat "$output_file"
  fi
}

self_test() {
  local temp_dir output
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-alpha-report.XXXXXX)"
  trap 'rm -rf "$temp_dir"' RETURN

  /bin/mkdir -p "$temp_dir/tracker"
  /bin/cp "$ROOT_DIR"/docs/alpha/templates/*.csv "$temp_dir/tracker/"

  output="$("$0" --tracker-dir "$temp_dir/tracker" --output "$temp_dir/report.md")"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Wrote safe alpha readiness report'
  /usr/bin/grep -q '# 10kmrr.life Alpha Readiness Report' "$temp_dir/report.md"
  /usr/bin/grep -q 'Single Recommended Action' "$temp_dir/report.md"
  /usr/bin/grep -q 'Private Tracker Audit' "$temp_dir/report.md"
  /usr/bin/grep -q 'Private Beta Readiness' "$temp_dir/report.md"
  /usr/bin/grep -q 'prepare the first alpha invite packet' "$temp_dir/report.md"
  assert_report_safe "$temp_dir/report.md"

  printf 'Alpha readiness report self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracker-dir) require_arg "$1" "${2:-}"; TRACKER_DIR="$2"; shift 2 ;;
    --output) require_arg "$1" "${2:-}"; OUTPUT_FILE="$2"; shift 2 ;;
    --stdout) PRINT_STDOUT=true; shift ;;
    --self-test) SELF_TEST=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
done

if [[ "$SELF_TEST" == "true" ]]; then
  self_test
  exit 0
fi

write_report "$OUTPUT_FILE"
