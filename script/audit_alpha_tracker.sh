#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
SELF_TEST=false

TRACKER_FILES=(
  "alpha-users.csv"
  "install-funnel.csv"
  "compatibility.csv"
  "local-smoke.csv"
  "pro-interest.csv"
  "weekly-review.csv"
)

usage() {
  cat <<EOF
Usage: $0 [--tracker-dir DIR] [--self-test] [--help]

Audits the private ignored alpha tracker for unsafe manual entries. The audit
prints only file, line, and issue type. It does not print row contents.

Options:
  --tracker-dir DIR  Tracker directory. Default: build/alpha-tracker.
  --self-test        Verify audit detection in a temporary tracker.
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

issue() {
  local file="$1"
  local line="$2"
  local label="$3"

  printf 'WARN  %s:%s %s\n' "$file" "$line" "$label"
}

header_matches_template() {
  local tracker_file="$1"
  local template_file="$2"

  [[ -f "$tracker_file" && -f "$template_file" ]] || return 1
  [[ "$(/usr/bin/head -1 "$tracker_file")" == "$(/usr/bin/head -1 "$template_file")" ]]
}

scan_file() {
  local file="$1"
  local template_file="$2"
  local rel_file="$3"
  local template_example=""
  local findings=0

  if [[ -f "$template_file" ]]; then
    template_example="$(/usr/bin/sed -n '2p' "$template_file")"
  fi

  while IFS= read -r result; do
    [[ -n "$result" ]] || continue
    issue "$rel_file" "${result%%:*}" "${result#*:}"
    findings=$((findings + 1))
  done < <(
    /usr/bin/awk -v template_example="$template_example" '
      NR <= 1 || length($0) == 0 || $0 == template_example { next }
      /sk_live_|sk_test_|rk_live_|rk_test_|whsec_/ { print NR ":secret-like token"; next }
      /[^[:space:]@,"]+@[^[:space:]@,"]+\.[^[:space:]@,"]+/ { print NR ":email-like contact data"; next }
      /\b(cus|sub|price|prod|pi|ch|in|cs|pm|seti|si)_[A-Za-z0-9]{8,}\b|client_secret|hosted_invoice_url|invoice_pdf|payment_method|customer_email/ { print NR ":Stripe object or raw Stripe field"; next }
      /[A-Z]{2,4}\$[0-9][0-9,]*(\.[0-9]{2})?|[A-Z]{3}[[:space:]]+[0-9][0-9,]*(\.[0-9]{2})?|\$[0-9][0-9,]*(\.[0-9]{2})?|([Mm][Rr][Rr]|[Aa][Rr][Rr]|[Rr]evenue|[Aa]mount)[[:space:]:=]+[0-9][0-9,]*(\.[0-9]{2})?/ { print NR ":obvious private money amount"; next }
      /(raw[ _-]?log|raw[ _-]?stripe|screenshot|screen shot|dashboard screenshot|customer name|invoice|payment data)/ { print NR ":raw logs, screenshots, or customer/payment-data wording"; next }
    ' "$file"
  )

  return "$findings"
}

audit_tracker() {
  local name tracker_file template_file missing=0 findings=0 scan_result=0

  if [[ ! -d "$TRACKER_DIR" ]]; then
    printf 'WARN  tracker directory missing: %s\n' "$TRACKER_DIR"
    printf 'NEXT  run: ./script/prepare_alpha_tracker.sh\n'
    return 1
  fi

  for name in "${TRACKER_FILES[@]}"; do
    tracker_file="$TRACKER_DIR/$name"
    template_file="$ROOT_DIR/docs/alpha/templates/$name"
    if [[ ! -s "$tracker_file" ]]; then
      printf 'WARN  missing tracker file: %s\n' "$name"
      missing=$((missing + 1))
      continue
    fi
    if ! header_matches_template "$tracker_file" "$template_file"; then
      printf 'WARN  %s: header differs from current template\n' "$name"
      findings=$((findings + 1))
    fi
  done

  if [[ "$missing" -gt 0 ]]; then
    printf 'NEXT  repair missing tracker files without replacing existing rows: ./script/prepare_alpha_tracker.sh\n'
    return 1
  fi

  for name in "${TRACKER_FILES[@]}"; do
    tracker_file="$TRACKER_DIR/$name"
    template_file="$ROOT_DIR/docs/alpha/templates/$name"
    scan_result=0
    scan_file "$tracker_file" "$template_file" "$name" || scan_result=$?
    findings=$((findings + scan_result))
  done

  if [[ "$findings" -gt 0 ]]; then
    printf 'WARN  alpha tracker audit found %s issue(s). Remove or sanitize those private rows before widening alpha.\n' "$findings"
    return 1
  fi

  printf 'PASS  alpha tracker audit found no unsafe manual entries.\n'
}

self_test() {
  local temp_dir output live_env
  live_env="live"
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-alpha-audit.XXXXXX)"
  trap 'rm -rf "$temp_dir"' RETURN

  /bin/mkdir -p "$temp_dir/tracker"
  /bin/cp "$ROOT_DIR"/docs/alpha/templates/*.csv "$temp_dir/tracker/"

  output="$("$0" --tracker-dir "$temp_dir/tracker")"
  printf '%s\n' "$output" | /usr/bin/grep -q 'PASS  alpha tracker audit found no unsafe manual entries'

  printf 'tester_bad,yes,15.5,apple_silicon,built_in,yes,approved,not_sent,not_started,unknown,unknown,none,"key rk_%s_1234567890abcdef","fix"\n' "$live_env" >>"$temp_dir/tracker/alpha-users.csv"
  if "$0" --tracker-dir "$temp_dir/tracker" >/tmp/10kmrr-alpha-audit-selftest.$$ 2>&1; then
    printf 'audit_alpha_tracker self-test failed: unsafe tracker row was accepted.\n' >&2
    /bin/rm -f /tmp/10kmrr-alpha-audit-selftest.$$
    exit 1
  fi
  output="$(cat /tmp/10kmrr-alpha-audit-selftest.$$)"
  /bin/rm -f /tmp/10kmrr-alpha-audit-selftest.$$
  printf '%s\n' "$output" | /usr/bin/grep -q 'alpha-users.csv:'
  printf '%s\n' "$output" | /usr/bin/grep -q 'secret-like token'
  if printf '%s\n' "$output" | /usr/bin/grep -Eq "rk_${live_env}_1234567890abcdef"; then
    printf 'audit_alpha_tracker self-test failed: audit output printed the unsafe value.\n' >&2
    exit 1
  fi

  printf 'Alpha tracker audit self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracker-dir) require_arg "$1" "${2:-}"; TRACKER_DIR="$2"; shift 2 ;;
    --self-test) SELF_TEST=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
done

if [[ "$SELF_TEST" == "true" ]]; then
  self_test
  exit 0
fi

audit_tracker
