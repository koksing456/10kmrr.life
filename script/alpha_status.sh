#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
NO_NETWORK=false
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 [--no-network] [--self-test] [--help]

Prints a lightweight public-alpha readiness summary without running the full
build/check gate and without printing Stripe keys or cached MRR values.

Options:
  --no-network  Skip GitHub Actions status lookup.
  --self-test   Verify output shape using local checks only.
  --help        Show this help.
EOF
}

status_line() {
  local level="$1"
  local message="$2"
  printf '%-5s %s\n' "$level" "$message"
}

section() {
  printf '\n==> %s\n' "$1"
}

github_repo_slug_for_remote() {
  local remote="$1"
  case "$remote" in
    git@github.com:*)
      printf '%s\n' "${remote#git@github.com:}" | /usr/bin/sed 's/\.git$//'
      ;;
    https://github.com/*)
      printf '%s\n' "${remote#https://github.com/}" | /usr/bin/sed 's/\.git$//'
      ;;
    *)
      return 1
      ;;
  esac
}

github_repo_slug() {
  local remote
  remote="$(/usr/bin/git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || true)"
  github_repo_slug_for_remote "$remote"
}

tracked_row_count() {
  local file="$1"
  local template_file="${2:-}"
  local template_example=""
  if [[ ! -f "$file" ]]; then
    printf '0'
    return
  fi
  if [[ -n "$template_file" && -f "$template_file" ]]; then
    template_example="$(/usr/bin/sed -n '2p' "$template_file")"
  fi
  /usr/bin/awk -v template_example="$template_example" '
    NR > 1 && length($0) > 0 && $0 != template_example { count++ }
    END { print count + 0 }
  ' "$file"
}

template_header_matches() {
  local generated_file="$1"
  local template_file="$2"

  [[ -f "$generated_file" && -f "$template_file" ]] || return 1
  [[ "$(/usr/bin/head -1 "$generated_file")" == "$(/usr/bin/head -1 "$template_file")" ]]
}

tracker_readme_current() {
  local readme="$TRACKER_DIR/README.md"
  [[ -f "$readme" ]] || return 1
  /usr/bin/grep -q 'Keep identity and contact mapping outside this repo' "$readme" &&
    /usr/bin/grep -q './script/prepare_alpha_invite_packet.sh' "$readme" &&
    /usr/bin/grep -q './script/run_local_smoke.sh --apply --full-reset --confirm-full-reset --record' "$readme" &&
    /usr/bin/grep -q './script/record_alpha_success.sh' "$readme" &&
    /usr/bin/grep -q './script/record_alpha_day7.sh' "$readme" &&
    /usr/bin/grep -q './script/alpha_weekly_summary.sh' "$readme" &&
    /usr/bin/grep -q 'Stripe object IDs' "$readme"
}

print_git_status() {
  local branch commit dirty

  section "Source"
  branch="$(git -C "$ROOT_DIR" branch --show-current 2>/dev/null || printf 'unknown')"
  commit="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
  dirty="$(git -C "$ROOT_DIR" status --short 2>/dev/null || true)"

  status_line "INFO" "branch: $branch"
  status_line "INFO" "commit: $commit"

  if [[ -z "$dirty" ]]; then
    status_line "PASS" "worktree is clean"
  else
    status_line "WARN" "worktree has local changes"
  fi
}

print_tracker_status() {
  local users_count install_count compatibility_count smoke_count pro_count weekly_count
  local audit_output

  section "Private alpha evidence"
  if [[ -d "$TRACKER_DIR" ]]; then
    if [[ -s "$TRACKER_DIR/alpha-users.csv" && -s "$TRACKER_DIR/install-funnel.csv" && -s "$TRACKER_DIR/compatibility.csv" && -s "$TRACKER_DIR/local-smoke.csv" && -s "$TRACKER_DIR/pro-interest.csv" && -s "$TRACKER_DIR/weekly-review.csv" ]]; then
      status_line "PASS" "private tracker exists: $TRACKER_DIR"
      if template_header_matches "$TRACKER_DIR/alpha-users.csv" "$ROOT_DIR/docs/alpha/templates/alpha-users.csv" &&
         template_header_matches "$TRACKER_DIR/install-funnel.csv" "$ROOT_DIR/docs/alpha/templates/install-funnel.csv" &&
         template_header_matches "$TRACKER_DIR/compatibility.csv" "$ROOT_DIR/docs/alpha/templates/compatibility.csv" &&
         template_header_matches "$TRACKER_DIR/local-smoke.csv" "$ROOT_DIR/docs/alpha/templates/local-smoke.csv" &&
         template_header_matches "$TRACKER_DIR/pro-interest.csv" "$ROOT_DIR/docs/alpha/templates/pro-interest.csv" &&
         template_header_matches "$TRACKER_DIR/weekly-review.csv" "$ROOT_DIR/docs/alpha/templates/weekly-review.csv"; then
        status_line "PASS" "tracker headers match current templates"
      else
        status_line "WARN" "tracker headers differ from current templates"
        status_line "NEXT" "if tracker CSVs have no private rows, refresh templates with: ./script/prepare_alpha_tracker.sh --force"
        status_line "NEXT" "if tracker CSVs have private rows, migrate those rows into fresh private templates instead of overwriting"
      fi
      if tracker_readme_current; then
        status_line "PASS" "tracker README matches current safety workflow"
      else
        status_line "WARN" "tracker README is missing current safety workflow"
        status_line "NEXT" "refresh tracker README without replacing CSV rows: ./script/prepare_alpha_tracker.sh --readme-only"
      fi
      users_count="$(tracked_row_count "$TRACKER_DIR/alpha-users.csv" "$ROOT_DIR/docs/alpha/templates/alpha-users.csv")"
      install_count="$(tracked_row_count "$TRACKER_DIR/install-funnel.csv" "$ROOT_DIR/docs/alpha/templates/install-funnel.csv")"
      compatibility_count="$(tracked_row_count "$TRACKER_DIR/compatibility.csv" "$ROOT_DIR/docs/alpha/templates/compatibility.csv")"
      smoke_count="$(tracked_row_count "$TRACKER_DIR/local-smoke.csv" "$ROOT_DIR/docs/alpha/templates/local-smoke.csv")"
      pro_count="$(tracked_row_count "$TRACKER_DIR/pro-interest.csv" "$ROOT_DIR/docs/alpha/templates/pro-interest.csv")"
      weekly_count="$(tracked_row_count "$TRACKER_DIR/weekly-review.csv" "$ROOT_DIR/docs/alpha/templates/weekly-review.csv")"
      status_line "INFO" "non-example alpha users tracked: $users_count"
      status_line "INFO" "non-example install attempts tracked: $install_count"
      status_line "INFO" "non-example compatibility checks tracked: $compatibility_count"
      status_line "INFO" "non-example local smoke checks tracked: $smoke_count"
      status_line "INFO" "non-example Pro follow-ups tracked: $pro_count"
      status_line "INFO" "non-example weekly reviews tracked: $weekly_count"
      audit_output="$("$ROOT_DIR/script/audit_alpha_tracker.sh" 2>&1 || true)"
      if printf '%s\n' "$audit_output" | /usr/bin/grep -q '^PASS'; then
        status_line "PASS" "tracker audit found no unsafe manual entries"
      else
        status_line "WARN" "tracker audit found issues or could not run"
        printf '%s\n' "$audit_output"
        status_line "NEXT" "sanitize tracker rows before widening alpha: ./script/audit_alpha_tracker.sh"
      fi
    else
      status_line "WARN" "tracker folder exists but expected CSV files are missing"
      status_line "NEXT" "repair missing tracker files without replacing existing rows: ./script/prepare_alpha_tracker.sh"
    fi
  else
    status_line "WARN" "private tracker not generated yet"
    status_line "NEXT" "run: ./script/prepare_alpha_tracker.sh"
  fi

  status_line "RULE" "do not collect Stripe keys, Stripe object IDs, exact private MRR, raw logs, raw Stripe responses, customer/payment data, or unsanitized screenshots"
}

print_signing_status() {
  section "Signing and notarization"
  if "$ROOT_DIR/script/signing_preflight.sh" --require-ready >/tmp/10kmrr-alpha-status-signing.$$ 2>&1; then
    status_line "PASS" "Developer ID signing prerequisites appear ready"
    status_line "NEXT" "private signed package: ./script/package_private_beta.sh --signed"
  else
    status_line "WARN" "Developer ID signed/notarized beta is not ready"
    status_line "NEXT" "details: ./script/signing_preflight.sh"
  fi
  /bin/rm -f "/tmp/10kmrr-alpha-status-signing.$$"
}

print_ci_status() {
  local latest repo

  section "GitHub Actions"
  if [[ "$NO_NETWORK" == "true" ]]; then
    status_line "INFO" "skipped network lookup"
    return
  fi

  if ! command -v gh >/dev/null 2>&1; then
    status_line "WARN" "gh CLI not available"
    status_line "NEXT" "run local gate: ./script/check.sh"
    return
  fi

  if ! repo="$(github_repo_slug)"; then
    status_line "WARN" "could not infer GitHub repo from origin remote"
    status_line "NEXT" "run local gate: ./script/check.sh"
    return
  fi

  latest="$(gh run list --repo "$repo" --limit 1 --json status,conclusion,headSha,displayTitle,workflowName --jq '.[] | [.workflowName, .displayTitle, .status, (.conclusion // ""), (.headSha[0:7])] | @tsv' 2>/dev/null || true)"
  if [[ -z "$latest" ]]; then
    status_line "WARN" "could not read latest GitHub Actions run"
    status_line "NEXT" "run local gate: ./script/check.sh"
    return
  fi

  IFS=$'\t' read -r workflow title status conclusion sha <<< "$latest"
  status_line "INFO" "$workflow: $title ($sha)"
  if [[ "$status" == "completed" && "$conclusion" == "success" ]]; then
    status_line "PASS" "latest CI passed"
  else
    status_line "WARN" "latest CI status: $status ${conclusion:-pending}"
    status_line "NEXT" "inspect: gh run list --repo $repo --limit 3"
  fi
}

print_next_actions() {
  section "Default next actions"
  status_line "NEXT" "before repo changes: ./script/check.sh"
  status_line "NEXT" "single recommended action: ./script/alpha_next_action.sh"
  status_line "NEXT" "write readiness report: ./script/alpha_readiness_report.sh"
  status_line "NEXT" "prepare tester invite packet: ./script/prepare_alpha_invite_packet.sh --tester-id tester_XXX --macos-version 15.x --cpu apple_silicon --display-setup built_in"
  status_line "NEXT" "start approved tester: ./script/start_alpha.sh"
  status_line "NEXT" "collect safe evidence: ./script/prepare_alpha_tracker.sh"
  status_line "NEXT" "audit private tracker: ./script/audit_alpha_tracker.sh"
  status_line "NEXT" "record support issue: ./script/record_alpha_support_issue.sh --tester-id tester_XXX --issue-type lock_screen --result fail"
  status_line "NEXT" "record successful tester: ./script/record_alpha_success.sh --tester-id tester_XXX --macos-version 15.x --cpu apple_silicon --display-setup built_in"
  status_line "NEXT" "record Day 7 follow-up: ./script/record_alpha_day7.sh --tester-id tester_XXX --retained-day-7 yes --overall-pro-signal medium"
  status_line "NEXT" "weekly alpha summary: ./script/alpha_weekly_summary.sh"
  status_line "NEXT" "debug tester issue: ./script/support_report.sh"
  status_line "NEXT" "check private beta gate: ./script/private_beta_readiness.sh"
}

self_test() {
  local output repo
  output="$("$0" --no-network)"
  printf '%s\n' "$output" | /usr/bin/grep -q '10kmrr.life alpha status'
  printf '%s\n' "$output" | /usr/bin/grep -q 'Private alpha evidence'
  printf '%s\n' "$output" | /usr/bin/grep -q 'Signing and notarization'
  printf '%s\n' "$output" | /usr/bin/grep -q 'Default next actions'
  repo="$(github_repo_slug_for_remote 'git@github.com:example/10kmrr.life.git')"
  [[ "$repo" == "example/10kmrr.life" ]]
  repo="$(github_repo_slug_for_remote 'https://github.com/example/10kmrr.life.git')"
  [[ "$repo" == "example/10kmrr.life" ]]
  if printf '%s\n' "$output" | /usr/bin/grep -Eq '(sk_live_|sk_test_|rk_live_|rk_test_|whsec_)'; then
    printf 'alpha_status self-test failed: output contained a secret-like token.\n' >&2
    exit 1
  fi
  printf 'Alpha status self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-network)
      NO_NETWORK=true
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

cd "$ROOT_DIR"

if [[ "$SELF_TEST" == "true" ]]; then
  self_test
  exit 0
fi

printf '10kmrr.life alpha status\n'
print_git_status
print_tracker_status
print_signing_status
print_ci_status
print_next_actions
