#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
TRACKER_DIR="$DEFAULT_TRACKER_DIR"
SELF_TEST=false
NO_SIGNING=false

usage() {
  cat <<EOF
Usage: $0 [--tracker-dir DIR] [--no-signing] [--self-test] [--help]

Prints the single highest-priority safe next action for the gated alpha.
It uses only aggregate tracker counts and never prints tester notes, Stripe
keys, exact MRR, contact data, raw logs, raw Stripe responses, or row contents.

Options:
  --tracker-dir DIR  Tracker directory. Default: build/alpha-tracker.
  --no-signing       Skip Developer ID/notary readiness check.
  --self-test        Verify recommendations with synthetic trackers.
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

shell_quote() {
  local value="$1"
  printf "'%s'" "${value//\'/\'\\\'\'}"
}

tracker_prepare_command() {
  if [[ "$TRACKER_DIR" == "$DEFAULT_TRACKER_DIR" ]]; then
    printf './script/alpha.sh tracker'
  else
    printf './script/alpha.sh tracker --output %s' "$(shell_quote "$TRACKER_DIR")"
  fi
}

tracker_audit_command() {
  if [[ "$TRACKER_DIR" == "$DEFAULT_TRACKER_DIR" ]]; then
    printf './script/alpha.sh audit'
  else
    printf './script/alpha.sh audit --tracker-dir %s' "$(shell_quote "$TRACKER_DIR")"
  fi
}

section() {
  printf '\n==> %s\n' "$1"
}

line() {
  local level="$1"
  local message="$2"
  printf '%-5s %s\n' "$level" "$message"
}

template_file() {
  printf '%s/docs/alpha/templates/%s' "$ROOT_DIR" "$1"
}

tracker_file() {
  printf '%s/%s' "$TRACKER_DIR" "$1"
}

ensure_tracker_shape() {
  local name
  local required=(
    "alpha-users.csv"
    "install-funnel.csv"
    "compatibility.csv"
    "local-smoke.csv"
    "pro-interest.csv"
    "weekly-review.csv"
  )

  [[ -d "$TRACKER_DIR" ]] || return 1
  for name in "${required[@]}"; do
    [[ -s "$(tracker_file "$name")" ]] || return 1
  done
}

csv_count() {
  local file="$1"
  local template="$2"
  local column="$3"
  local predicate="$4"

  [[ -f "$file" && -f "$template" ]] || { printf '0'; return; }

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
      } else if (predicate == "not_pass" && value != "pass") {
        count++
      } else if (predicate == "install_warning_or_failure" && (value == "warn" || value == "fail")) {
        count++
      } else if (predicate == "pro_signal" && (value == "medium" || value == "high")) {
        count++
      }
    }
    END { print count + 0 }
  ' "$file"
}

successful_install_count() {
  local file template
  file="$(tracker_file install-funnel.csv)"
  template="$(template_file install-funnel.csv)"
  [[ -f "$file" && -f "$template" ]] || { printf '0'; return; }

  /usr/bin/awk -v template_example="$(/usr/bin/sed -n '2p' "$template")" '
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
          if (field_index == wanted) return field
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
      if (csvfield($0, 7) == "yes" && csvfield($0, 8) == "yes") {
        testers[csvfield($0, 1)] = 1
      }
    }
    END {
      count = 0
      for (tester in testers) count++
      print count + 0
    }
  ' "$file"
}

compatibility_pass_count() {
  local file template
  file="$(tracker_file compatibility.csv)"
  template="$(template_file compatibility.csv)"
  [[ -f "$file" && -f "$template" ]] || { printf '0'; return; }

  /usr/bin/awk -v template_example="$(/usr/bin/sed -n '2p' "$template")" '
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
          if (field_index == wanted) return field
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
      if (csvfield($0, 8) == "yes" && csvfield($0, 9) == "yes" && csvfield($0, 10) == "yes" && csvfield($0, 11) == "pass") {
        testers[csvfield($0, 1)] = 1
      }
    }
    END {
      count = 0
      for (tester in testers) count++
      print count + 0
    }
  ' "$file"
}

local_smoke_pass_count() {
  local file template
  file="$(tracker_file local-smoke.csv)"
  template="$(template_file local-smoke.csv)"
  [[ -f "$file" && -f "$template" ]] || { printf '0'; return; }

  /usr/bin/awk -v template_example="$(/usr/bin/sed -n '2p' "$template")" '
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
          if (field_index == wanted) return field
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
      if (csvfield($0, 2) == "pass" && csvfield($0, 3) == "pass" && csvfield($0, 4) == "pass" && csvfield($0, 5) == "pass" && csvfield($0, 6) == "pass" && csvfield($0, 7) == "pass" && csvfield($0, 8) == "pass") {
        count++
      }
    }
    END { print count + 0 }
  ' "$file"
}

install_issue_count() {
  local file template
  file="$(tracker_file install-funnel.csv)"
  template="$(template_file install-funnel.csv)"
  [[ -f "$file" && -f "$template" ]] || { printf '0'; return; }

  /usr/bin/awk -v template_example="$(/usr/bin/sed -n '2p' "$template")" '
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
          if (field_index == wanted) return field
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
      stage = csvfield($0, 3)
      build = csvfield($0, 4)
      installed = csvfield($0, 7)
      saw_mrr = csvfield($0, 8)
      if (stage == "closed_lost" || build == "warn" || build == "fail" || installed == "no" || saw_mrr == "no") {
        count++
      }
    }
    END { print count + 0 }
  ' "$file"
}

signing_ready() {
  [[ "$NO_SIGNING" == "true" ]] && return 1
  "$ROOT_DIR/script/signing_preflight.sh" --require-ready >/dev/null 2>&1
}

emit_action() {
  local priority="$1"
  local reason="$2"
  local command="$3"
  local command_label="RUN"
  local has_placeholder=false

  if printf '%s\n' "$command" | /usr/bin/grep -Eq 'tester_XXX|15\.x' &&
     ! printf '%s\n' "$command" | /usr/bin/grep -q -- '--dry-run'; then
    command_label="TEMPLATE"
    has_placeholder=true
  fi

  printf '10kmrr.life alpha next action\n'
  section "Recommendation"
  line "DO" "$priority"
  line "WHY" "$reason"
  line "$command_label" "$command"
  section "Boundary"
  line "RULE" "do not collect Stripe keys, Stripe object IDs, exact MRR, raw logs, raw Stripe responses, customer/payment data, contact data, or unsanitized screenshots"
  if [[ "$has_placeholder" == "true" ]]; then
    line "RULE" "replace placeholder values before running this template command"
  fi
}

recommend() {
  local approved_users install_rows install_success install_failures compatibility_success compatibility_failures smoke_success pro_followups weekly_reviews pro_signals

  if ! ensure_tracker_shape; then
    emit_action \
      "prepare private alpha tracker" \
      "tracker files are missing or incomplete" \
      "$(tracker_prepare_command)"
    return
  fi

  if ! "$ROOT_DIR/script/audit_alpha_tracker.sh" --tracker-dir "$TRACKER_DIR" >/dev/null 2>&1; then
    emit_action \
      "sanitize private tracker rows" \
      "tracker audit found unsafe manual entries or header drift" \
      "$(tracker_audit_command)"
    return
  fi

  approved_users="$(csv_count "$(tracker_file alpha-users.csv)" "$(template_file alpha-users.csv)" 6 yes)"
  install_rows="$(csv_count "$(tracker_file install-funnel.csv)" "$(template_file install-funnel.csv)" 1 any)"
  install_success="$(successful_install_count)"
  install_failures="$(install_issue_count)"
  compatibility_success="$(compatibility_pass_count)"
  compatibility_failures="$(csv_count "$(tracker_file compatibility.csv)" "$(template_file compatibility.csv)" 11 not_pass)"
  smoke_success="$(local_smoke_pass_count)"
  pro_followups="$(csv_count "$(tracker_file pro-interest.csv)" "$(template_file pro-interest.csv)" 1 any)"
  weekly_reviews="$(csv_count "$(tracker_file weekly-review.csv)" "$(template_file weekly-review.csv)" 1 any)"
  pro_signals="$(csv_count "$(tracker_file pro-interest.csv)" "$(template_file pro-interest.csv)" 12 pro_signal)"

  section "Current Aggregate State"
  line "INFO" "approved testers: $approved_users"
  line "INFO" "install attempts: $install_rows"
  line "INFO" "successful installs with MRR: $install_success"
  line "INFO" "Lock Screen compatibility passes: $compatibility_success"
  line "INFO" "local smoke passes: $smoke_success"
  line "INFO" "Day 7 follow-ups: $pro_followups"
  line "INFO" "weekly reviews: $weekly_reviews"
  line "INFO" "medium/high Pro signals: $pro_signals"

  if [[ "$approved_users" -eq 0 && "$install_rows" -eq 0 ]]; then
    emit_action \
      "read the first-tester checklist, then print the no-write flow" \
      "private beta evidence cannot move until a real tester is approved; use the checklist and dry-run flow first to avoid fake tracker rows" \
      "./script/alpha.sh first-tester"
    return
  fi

  if [[ "$approved_users" -gt 0 && "$install_rows" -lt "$approved_users" ]]; then
    emit_action \
      "start approved tester and collect install evidence" \
      "there are approved testers without install evidence rows" \
      "./script/alpha.sh start --tester-id tester_XXX"
    return
  fi

  if [[ "$install_failures" -gt 0 || "$compatibility_failures" -gt 0 ]]; then
    emit_action \
      "resolve or record support blockers before widening alpha" \
      "tracker has warn/fail support evidence" \
      "./script/alpha.sh weekly"
    return
  fi

  if [[ "$install_success" -lt 5 || "$compatibility_success" -lt 5 ]]; then
    emit_action \
      "collect successful Apple Silicon tester evidence" \
      "private beta gate needs 5 successful installs and 5 Lock Screen compatibility passes" \
      "./script/alpha.sh success --tester-id tester_XXX --macos-version 15.x --cpu apple_silicon --display-setup built_in"
    return
  fi

  if [[ "$smoke_success" -lt 1 ]]; then
    emit_action \
      "record clean local smoke evidence" \
      "private beta gate needs one local install/repair/support/uninstall smoke pass" \
      "./script/alpha.sh smoke --apply --full-reset --confirm-full-reset --record"
    return
  fi

  if [[ "$pro_followups" -lt "$install_success" ]]; then
    emit_action \
      "record Day 7 retention and Pro signal" \
      "some successful testers do not yet have Day 7 follow-up evidence" \
      "./script/alpha.sh day7 --tester-id tester_XXX --retained-day-7 yes --overall-pro-signal medium"
    return
  fi

  if [[ "$weekly_reviews" -eq 0 ]]; then
    emit_action \
      "write the first weekly alpha review" \
      "safe aggregate evidence exists but no weekly decision row has been recorded" \
      "./script/alpha.sh weekly"
    return
  fi

  if ! signing_ready; then
    emit_action \
      "finish Developer ID signing and notary setup" \
      "evidence path is ready enough for signing work, but signing preflight is not ready" \
      "./script/alpha.sh signing"
    return
  fi

  emit_action \
    "create signed private beta package" \
    "alpha evidence, local smoke, weekly review, and signing are ready" \
    "./script/alpha.sh package --signed"
}

self_test() {
  local temp_dir output
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-alpha-next.XXXXXX)"
  trap 'rm -rf "$temp_dir"' RETURN

  /bin/mkdir -p "$temp_dir/tracker"
  /bin/cp "$ROOT_DIR"/docs/alpha/templates/*.csv "$temp_dir/tracker/"

  output="$("$0" --tracker-dir "$temp_dir/tracker" --no-signing)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'read the first-tester checklist'
  printf '%s\n' "$output" | /usr/bin/grep -q './script/alpha.sh first-tester'
  printf '%s\n' "$output" | /usr/bin/grep -q 'Stripe object IDs'

  /bin/rm -rf "$temp_dir/missing-tracker"
  output="$("$0" --tracker-dir "$temp_dir/missing-tracker" --no-signing)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'prepare private alpha tracker'
  printf '%s\n' "$output" | /usr/bin/grep -q "./script/alpha.sh tracker --output '$temp_dir/missing-tracker'"

  "$ROOT_DIR/script/approve_alpha_tester.sh" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_001 \
    --macos-version 15.5 \
    --cpu apple_silicon \
    --display-setup built_in >/dev/null
  output="$("$0" --tracker-dir "$temp_dir/tracker" --no-signing)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'start approved tester and collect install evidence'
  printf '%s\n' "$output" | /usr/bin/grep -q '^TEMPLATE'
  printf '%s\n' "$output" | /usr/bin/grep -q './script/alpha.sh start --tester-id tester_XXX'

  "$ROOT_DIR/script/record_alpha_support_issue.sh" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_001 \
    --issue-type key \
    --result warn \
    --blocker 'restricted key not configured yet' >/dev/null
  output="$("$0" --tracker-dir "$temp_dir/tracker" --no-signing)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'resolve or record support blockers'

  /bin/cp "$ROOT_DIR"/docs/alpha/templates/*.csv "$temp_dir/tracker/"
  "$ROOT_DIR/script/record_alpha_success.sh" \
    --tracker-dir "$temp_dir/tracker" \
    --tester-id tester_001 \
    --evidence-date 2026-06-08 \
    --macos-version 15.5 \
    --cpu apple_silicon \
    --display-setup built_in >/dev/null
  output="$("$0" --tracker-dir "$temp_dir/tracker" --no-signing)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'collect successful Apple Silicon tester evidence'
  printf '%s\n' "$output" | /usr/bin/grep -q '^TEMPLATE'
  printf '%s\n' "$output" | /usr/bin/grep -q 'replace placeholder values before running this template command'

  /bin/cp "$ROOT_DIR"/docs/alpha/templates/*.csv "$temp_dir/tracker/"
  for index in 1 2 3 4 5; do
    "$ROOT_DIR/script/record_alpha_success.sh" \
      --tracker-dir "$temp_dir/tracker" \
      --tester-id "tester_00$index" \
      --evidence-date 2026-06-08 \
      --macos-version 15.5 \
      --cpu apple_silicon \
      --display-setup built_in >/dev/null
  done
  output="$("$0" --tracker-dir "$temp_dir/tracker" --no-signing)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'record clean local smoke evidence'

  printf 'Alpha next action self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracker-dir) require_arg "$1" "${2:-}"; TRACKER_DIR="$2"; shift 2 ;;
    --no-signing) NO_SIGNING=true; shift ;;
    --self-test) SELF_TEST=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
done

if [[ "$SELF_TEST" == "true" ]]; then
  self_test
  exit 0
fi

recommend
