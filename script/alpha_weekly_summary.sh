#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
WEEK_START="$(/bin/date '+%Y-%m-%d')"
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 [options]

Prints a safe aggregate weekly alpha summary from the private ignored tracker.
It does not print tester notes, blockers, exact MRR, contact data, raw logs, or
raw Stripe responses.

Options:
  --tracker-dir DIR        Tracker directory. Default: build/alpha-tracker.
  --week-start YYYY-MM-DD  Week start to use in the suggested recorder command.
  --self-test              Verify summary output using a temporary tracker.
  --help                   Show this help.
EOF
}

require_arg() {
  local option="$1"
  if [[ $# -lt 2 || "${2:-}" == --* ]]; then
    printf 'Missing value for %s.\n' "$option" >&2
    exit 64
  fi
}

ensure_tracker() {
  local required=(
    "alpha-users.csv"
    "install-funnel.csv"
    "compatibility.csv"
    "local-smoke.csv"
    "pro-interest.csv"
    "weekly-review.csv"
  )
  local name

  for name in "${required[@]}"; do
    if [[ ! -s "$TRACKER_DIR/$name" ]]; then
      printf 'Alpha tracker file missing: %s\n' "$TRACKER_DIR/$name" >&2
      printf 'Run ./script/prepare_alpha_tracker.sh first.\n' >&2
      exit 1
    fi
  done
}

csv_value() {
  local file="$1"
  local template="$2"
  local column="$3"
  local predicate="$4"

  /usr/bin/awk -v template_example="$(/usr/bin/sed -n '2p' "$template")" -v column="$column" -v predicate="$predicate" '
    function csvfield(line, wanted,    i, c, quoted, field, field_index) {
      quoted = 0
      field = ""
      field_index = 1
      for (i = 1; i <= length(line); i++) {
        c = substr(line, i, 1)
        if (c == "\"") {
          if (quoted && substr(line, i + 1, 1) == "\"") {
            field = field "\""
            i++
          } else {
            quoted = !quoted
          }
        } else if (c == "," && !quoted) {
          if (field_index == wanted) {
            return field
          }
          field = ""
          field_index++
        } else {
          field = field c
        }
      }
      return field_index == wanted ? field : ""
    }
    NR <= 1 || length($0) == 0 || $0 == template_example { next }
    {
      value = csvfield($0, column)
      if (predicate == "any") {
        count++
      } else if (predicate == value) {
        count++
      } else if (predicate == "pro_signal" && (value == "medium" || value == "high")) {
        count++
      } else if (predicate == "not_pass" && value != "pass") {
        count++
      } else if (predicate == "install_failure" && (value == "fail" || value == "warn")) {
        count++
      }
    }
    END { print count + 0 }
  ' "$file"
}

emit_summary() {
  ensure_tracker

  local users approved retained closed_lost installs saw_mrr install_warn_fail compatibility compatibility_pass compatibility_failures smoke smoke_pass pro_followups pro_retained pro_signals weekly_reviews
  local support_load setup_failure_rate secret_sharing_risk scope_pull decision next_action

  users="$(csv_value "$TRACKER_DIR/alpha-users.csv" "$ROOT_DIR/docs/alpha/templates/alpha-users.csv" 1 any)"
  approved="$(csv_value "$TRACKER_DIR/alpha-users.csv" "$ROOT_DIR/docs/alpha/templates/alpha-users.csv" 6 yes)"
  retained="$(csv_value "$TRACKER_DIR/alpha-users.csv" "$ROOT_DIR/docs/alpha/templates/alpha-users.csv" 11 yes)"
  closed_lost="$(csv_value "$TRACKER_DIR/alpha-users.csv" "$ROOT_DIR/docs/alpha/templates/alpha-users.csv" 7 closed_lost)"
  installs="$(csv_value "$TRACKER_DIR/install-funnel.csv" "$ROOT_DIR/docs/alpha/templates/install-funnel.csv" 1 any)"
  saw_mrr="$(csv_value "$TRACKER_DIR/install-funnel.csv" "$ROOT_DIR/docs/alpha/templates/install-funnel.csv" 8 yes)"
  install_warn_fail="$(csv_value "$TRACKER_DIR/install-funnel.csv" "$ROOT_DIR/docs/alpha/templates/install-funnel.csv" 4 install_failure)"
  compatibility="$(csv_value "$TRACKER_DIR/compatibility.csv" "$ROOT_DIR/docs/alpha/templates/compatibility.csv" 1 any)"
  compatibility_pass="$(csv_value "$TRACKER_DIR/compatibility.csv" "$ROOT_DIR/docs/alpha/templates/compatibility.csv" 11 pass)"
  compatibility_failures="$(csv_value "$TRACKER_DIR/compatibility.csv" "$ROOT_DIR/docs/alpha/templates/compatibility.csv" 11 not_pass)"
  smoke="$(csv_value "$TRACKER_DIR/local-smoke.csv" "$ROOT_DIR/docs/alpha/templates/local-smoke.csv" 1 any)"
  smoke_pass="$(csv_value "$TRACKER_DIR/local-smoke.csv" "$ROOT_DIR/docs/alpha/templates/local-smoke.csv" 8 pass)"
  pro_followups="$(csv_value "$TRACKER_DIR/pro-interest.csv" "$ROOT_DIR/docs/alpha/templates/pro-interest.csv" 1 any)"
  pro_retained="$(csv_value "$TRACKER_DIR/pro-interest.csv" "$ROOT_DIR/docs/alpha/templates/pro-interest.csv" 3 yes)"
  pro_signals="$(csv_value "$TRACKER_DIR/pro-interest.csv" "$ROOT_DIR/docs/alpha/templates/pro-interest.csv" 12 pro_signal)"
  weekly_reviews="$(csv_value "$TRACKER_DIR/weekly-review.csv" "$ROOT_DIR/docs/alpha/templates/weekly-review.csv" 1 any)"

  support_load="unknown"
  setup_failure_rate="unknown"
  secret_sharing_risk="none"
  scope_pull="none"
  decision="continue"
  next_action="invite next tester"

  if [[ "$install_warn_fail" -gt 0 ]]; then
    setup_failure_rate="medium"
    support_load="medium"
    next_action="review install blockers before next invite"
  elif [[ "$installs" -gt 0 ]]; then
    setup_failure_rate="low"
    support_load="low"
  fi

  if [[ "$compatibility_failures" -gt 0 ]]; then
    decision="narrow"
    next_action="fix compatibility blockers before widening alpha"
  fi

  if [[ "$pro_signals" -gt 0 && "$compatibility_failures" -eq 0 ]]; then
    next_action="ask retained testers for Pro willingness"
  fi

  printf '10kmrr.life weekly alpha summary\n'
  printf '\n==> Safe aggregate counts\n'
  printf 'alpha users tracked: %s\n' "$users"
  printf 'approved testers: %s\n' "$approved"
  printf 'install attempts: %s\n' "$installs"
  printf 'install rows that saw MRR: %s\n' "$saw_mrr"
  printf 'Lock Screen compatibility checks: %s\n' "$compatibility"
  printf 'Lock Screen compatibility passes: %s\n' "$compatibility_pass"
  printf 'local smoke rows: %s\n' "$smoke"
  printf 'local smoke passes: %s\n' "$smoke_pass"
  printf 'Day 7 follow-ups: %s\n' "$pro_followups"
  printf 'Day 7 retained: %s\n' "$pro_retained"
  printf 'alpha-users retained snapshots: %s\n' "$retained"
  printf 'closed-lost snapshots: %s\n' "$closed_lost"
  printf 'medium/high Pro signals: %s\n' "$pro_signals"
  printf 'prior weekly reviews: %s\n' "$weekly_reviews"

  if [[ "$users" -eq 0 && "$installs" -eq 0 && "$compatibility" -eq 0 && "$smoke" -eq 0 && "$pro_followups" -eq 0 ]]; then
    printf '\n==> Weekly review not suggested yet\n'
    printf 'NEXT  collect first alpha evidence before writing a weekly review row.\n'
    printf 'NEXT  single recommended action: ./script/alpha.sh next\n'
    printf 'NEXT  preview invite without writing evidence: ./script/alpha.sh invite --tester-id tester_XXX --macos-version 15.x --cpu apple_silicon --display-setup built_in --dry-run\n'
    printf '\nRULE  keep identity, contact mapping, exact MRR, Stripe keys, raw logs, raw Stripe responses, customer/payment data, and unsanitized screenshots out of this summary.\n'
    return
  fi

  printf '\n==> Suggested weekly review row\n'
  printf './script/record_alpha_weekly_review.sh \\\n'
  printf '  --week-start %s \\\n' "$WEEK_START"
  printf '  --support-load %s \\\n' "$support_load"
  printf '  --setup-failure-rate %s \\\n' "$setup_failure_rate"
  printf '  --retention-count %s \\\n' "$pro_retained"
  printf '  --pro-signal-count %s \\\n' "$pro_signals"
  printf '  --compatibility-failures %s \\\n' "$compatibility_failures"
  printf '  --secret-sharing-risk %s \\\n' "$secret_sharing_risk"
  printf '  --scope-pull %s \\\n' "$scope_pull"
  printf '  --decision %s \\\n' "$decision"
  printf '  --next-action %q\n' "$next_action"

  printf '\nRULE  keep identity, contact mapping, exact MRR, Stripe keys, raw logs, raw Stripe responses, customer/payment data, and unsanitized screenshots out of this summary.\n'
}

self_test() {
  local temp_dir output live_env
  live_env="live"
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-alpha-summary.XXXXXX)"
  trap 'rm -rf "$temp_dir"' RETURN

  /bin/mkdir -p "$temp_dir/tracker"
  /bin/cp "$ROOT_DIR"/docs/alpha/templates/*.csv "$temp_dir/tracker/"

  output="$("$0" --tracker-dir "$temp_dir/tracker" --week-start 2026-06-15)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Weekly review not suggested yet'
  printf '%s\n' "$output" | /usr/bin/grep -q 'collect first alpha evidence before writing a weekly review row'
  if printf '%s\n' "$output" | /usr/bin/grep -q './script/record_alpha_weekly_review.sh'; then
    printf 'alpha_weekly_summary self-test failed: empty tracker suggested a weekly review row.\n' >&2
    exit 1
  fi

  "$ROOT_DIR/script/record_alpha_success.sh" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_001 \
    --evidence-date 2026-06-08 \
    --macos-version 15.5 \
    --cpu apple_silicon \
    --display-setup built_in >/dev/null
  "$ROOT_DIR/script/record_alpha_day7.sh" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_001 \
    --follow-up-date 2026-06-15 \
    --retained-day-7 yes \
    --overall-pro-signal high \
    --notes 'kept it on for day 7' >/dev/null

  output="$("$0" --tracker-dir "$temp_dir/tracker" --week-start 2026-06-15)"
  printf '%s\n' "$output" | /usr/bin/grep -q '10kmrr.life weekly alpha summary'
  printf '%s\n' "$output" | /usr/bin/grep -q 'install rows that saw MRR: 1'
  printf '%s\n' "$output" | /usr/bin/grep -q 'Day 7 retained: 1'
  printf '%s\n' "$output" | /usr/bin/grep -q 'medium/high Pro signals: 1'
  printf '%s\n' "$output" | /usr/bin/grep -q -- '--decision continue'

  if printf '%s\n' "$output" | /usr/bin/grep -Eq "(sk_live_|sk_test_|rk_${live_env}_|rk_test_|whsec_|MRR US\\$|founder@example\\.com|cus_[A-Za-z0-9]+)"; then
    printf 'alpha_weekly_summary self-test failed: output contained sensitive-looking data.\n' >&2
    exit 1
  fi

  printf 'Alpha weekly summary self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracker-dir) require_arg "$1" "${2:-}"; TRACKER_DIR="$2"; shift 2 ;;
    --week-start) require_arg "$1" "${2:-}"; WEEK_START="$2"; shift 2 ;;
    --self-test) SELF_TEST=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
done

if [[ "$SELF_TEST" == "true" ]]; then
  self_test
  exit 0
fi

emit_summary
