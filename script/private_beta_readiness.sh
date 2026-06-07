#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
REQUIRE_READY=false
SELF_TEST=false
EXCLUDE_INTEL=false

usage() {
  cat <<EOF
Usage: $0 [--tracker-dir DIR] [--require-ready] [--exclude-intel] [--self-test] [--help]

Summarizes whether private beta packaging has enough local evidence to proceed.
It does not print Stripe keys, MRR values, raw logs, raw Stripe responses, or
tester contact details.

Options:
  --tracker-dir DIR  Tracker directory. Default: build/alpha-tracker.
  --require-ready    Exit non-zero unless evidence and signing are ready.
  --exclude-intel    Do not require Intel Lock Screen compatibility evidence.
                     Release notes must say Intel is excluded/unverified.
  --self-test        Verify parser and readiness rules with synthetic trackers.
  --help             Show this help.
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

strip_quotes() {
  local value="$1"
  value="${value%\"}"
  value="${value#\"}"
  value="${value//\"\"/\"}"
  printf '%s' "$value"
}

csv_count_rows() {
  local file="$1"
  local template_file="$2"
  local template_example=""

  [[ -f "$file" ]] || { printf '0'; return; }
  template_example="$(/usr/bin/sed -n '2p' "$template_file" 2>/dev/null || true)"

  /usr/bin/awk -v template_example="$template_example" '
    NR > 1 && length($0) > 0 && $0 != template_example { count++ }
    END { print count + 0 }
  ' "$file"
}

successful_installs() {
  local file="$1"
  local template_file="$ROOT_DIR/docs/alpha/templates/install-funnel.csv"
  local template_example
  template_example="$(/usr/bin/sed -n '2p' "$template_file")"

  /usr/bin/awk -F, -v template_example="$template_example" '
    function clean(value) {
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      return value
    }
    NR > 1 && length($0) > 0 && $0 != template_example {
      installed=clean($7)
      saw_mrr=clean($8)
      if (installed == "yes" && saw_mrr == "yes") {
        testers[clean($1)] = 1
      }
    }
    END {
      count=0
      for (tester in testers) count++
      print count + 0
    }
  ' "$file" 2>/dev/null || printf '0'
}

failed_install_attempts() {
  local file="$1"
  local template_file="$ROOT_DIR/docs/alpha/templates/install-funnel.csv"
  local template_example
  template_example="$(/usr/bin/sed -n '2p' "$template_file")"

  /usr/bin/awk -F, -v template_example="$template_example" '
    function clean(value) {
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      return value
    }
    NR > 1 && length($0) > 0 && $0 != template_example {
      stage=clean($3)
      build=clean($4)
      installed=clean($7)
      saw_mrr=clean($8)
      if (stage == "closed_lost" || build == "fail" || installed == "no" || saw_mrr == "no") {
        count++
      }
    }
    END { print count + 0 }
  ' "$file" 2>/dev/null || printf '0'
}

compatibility_passes() {
  local file="$1"
  local template_file="$ROOT_DIR/docs/alpha/templates/compatibility.csv"
  local template_example
  template_example="$(/usr/bin/sed -n '2p' "$template_file")"

  /usr/bin/awk -F, -v template_example="$template_example" '
    function clean(value) {
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      return value
    }
    NR > 1 && length($0) > 0 && $0 != template_example {
      lock_visible=clean($8)
      unlock_hides=clean($9)
      launchagent=clean($10)
      result=clean($11)
      if (result == "pass" && lock_visible == "yes" && unlock_hides == "yes" && launchagent == "yes") {
        testers[clean($1)] = 1
      }
    }
    END {
      count=0
      for (tester in testers) count++
      print count + 0
    }
  ' "$file" 2>/dev/null || printf '0'
}

intel_compatibility_passes() {
  local file="$1"
  local template_file="$ROOT_DIR/docs/alpha/templates/compatibility.csv"
  local template_example
  template_example="$(/usr/bin/sed -n '2p' "$template_file")"

  /usr/bin/awk -F, -v template_example="$template_example" '
    function clean(value) {
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      return value
    }
    NR > 1 && length($0) > 0 && $0 != template_example {
      cpu=clean($4)
      lock_visible=clean($8)
      unlock_hides=clean($9)
      launchagent=clean($10)
      result=clean($11)
      if (cpu == "intel" && result == "pass" && lock_visible == "yes" && unlock_hides == "yes" && launchagent == "yes") {
        testers[clean($1)] = 1
      }
    }
    END {
      count=0
      for (tester in testers) count++
      print count + 0
    }
  ' "$file" 2>/dev/null || printf '0'
}

repeated_private_api_failures() {
  local file="$1"
  local template_file="$ROOT_DIR/docs/alpha/templates/compatibility.csv"
  local template_example
  template_example="$(/usr/bin/sed -n '2p' "$template_file")"

  /usr/bin/awk -F, -v template_example="$template_example" '
    function clean(value) {
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      return value
    }
    NR > 1 && length($0) > 0 && $0 != template_example {
      macos=clean($3)
      preview=clean($7)
      lock_visible=clean($8)
      result=clean($11)
      if (macos == "") macos = "unknown"
      if (preview == "fail" || lock_visible == "no" || result == "fail") {
        failures[macos]++
      }
    }
    END {
      repeated=0
      for (macos in failures) {
        if (failures[macos] >= 2) repeated=1
      }
      print repeated
    }
  ' "$file" 2>/dev/null || printf '0'
}

local_smoke_passes() {
  local file="$1"
  local template_file="$ROOT_DIR/docs/alpha/templates/local-smoke.csv"
  local template_example
  template_example="$(/usr/bin/sed -n '2p' "$template_file")"

  /usr/bin/awk -F, -v template_example="$template_example" '
    function clean(value) {
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      return value
    }
    NR > 1 && length($0) > 0 && $0 != template_example {
      build=clean($2)
      install=clean($3)
      diagnose=clean($4)
      repair=clean($5)
      report=clean($6)
      uninstall=clean($7)
      result=clean($8)
      if (build == "pass" && install == "pass" && diagnose == "pass" && repair == "pass" && report == "pass" && uninstall == "pass" && result == "pass") {
        count++
      }
    }
    END { print count + 0 }
  ' "$file" 2>/dev/null || printf '0'
}

signing_ready() {
  if [[ "${TENKMRR_SIGNING_READY_OVERRIDE:-}" == "pass" ]]; then
    return 0
  fi
  if [[ "${TENKMRR_SIGNING_READY_OVERRIDE:-}" == "fail" ]]; then
    return 1
  fi
  "$ROOT_DIR/script/signing_preflight.sh" --require-ready >/dev/null 2>&1
}

print_source_status() {
  section "Source"
  local dirty commit
  commit="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
  dirty="$(git -C "$ROOT_DIR" status --short 2>/dev/null || true)"
  status_line "INFO" "commit: $commit"
  if [[ -z "$dirty" ]]; then
    status_line "PASS" "worktree is clean"
  else
    status_line "WARN" "worktree has local changes"
  fi
}

print_readiness() {
  local ready=0
  local install_file="$TRACKER_DIR/install-funnel.csv"
  local compatibility_file="$TRACKER_DIR/compatibility.csv"
  local smoke_file="$TRACKER_DIR/local-smoke.csv"
  local install_template="$ROOT_DIR/docs/alpha/templates/install-funnel.csv"
  local compatibility_template="$ROOT_DIR/docs/alpha/templates/compatibility.csv"
  local smoke_template="$ROOT_DIR/docs/alpha/templates/local-smoke.csv"
  local install_rows compatibility_rows install_success install_failures compatibility_success intel_success repeated_failures
  local smoke_rows smoke_success
  local failure_rate=0

  printf '10kmrr.life private beta readiness\n'
  print_source_status

  section "Alpha evidence"
  if [[ ! -s "$install_file" || ! -s "$compatibility_file" || ! -s "$smoke_file" ]]; then
    status_line "WARN" "private tracker is missing install, compatibility, or local-smoke CSVs"
    status_line "NEXT" "repair missing tracker files without replacing existing rows: ./script/prepare_alpha_tracker.sh"
    ready=1
  else
    install_rows="$(csv_count_rows "$install_file" "$install_template")"
    compatibility_rows="$(csv_count_rows "$compatibility_file" "$compatibility_template")"
    smoke_rows="$(csv_count_rows "$smoke_file" "$smoke_template")"
    install_success="$(successful_installs "$install_file")"
    install_failures="$(failed_install_attempts "$install_file")"
    compatibility_success="$(compatibility_passes "$compatibility_file")"
    intel_success="$(intel_compatibility_passes "$compatibility_file")"
    repeated_failures="$(repeated_private_api_failures "$compatibility_file")"
    smoke_success="$(local_smoke_passes "$smoke_file")"

    if [[ "$install_rows" -gt 0 ]]; then
      failure_rate=$(( install_failures * 100 / install_rows ))
    fi

    if [[ "$install_success" -ge 5 ]]; then
      status_line "PASS" "successful installs with MRR seen: $install_success/5"
    else
      status_line "WARN" "successful installs with MRR seen: $install_success/5"
      ready=1
    fi

    if [[ "$compatibility_success" -ge 5 ]]; then
      status_line "PASS" "Lock Screen compatibility passes: $compatibility_success/5"
    else
      status_line "WARN" "Lock Screen compatibility passes: $compatibility_success/5"
      ready=1
    fi

    if [[ "$EXCLUDE_INTEL" == "true" ]]; then
      status_line "WARN" "Intel compatibility excluded from this private beta gate"
      status_line "NEXT" "release notes must say Intel Lock Screen behavior is unverified/excluded"
    elif [[ "$intel_success" -ge 2 ]]; then
      status_line "PASS" "Intel compatibility passes for universal beta: $intel_success/2"
    else
      status_line "WARN" "Intel compatibility passes for universal beta: $intel_success/2"
      status_line "NEXT" "keep Intel out of private beta notes or collect 2 Intel passes"
      ready=1
    fi

    if [[ "$install_rows" -eq 0 ]]; then
      status_line "WARN" "install failure rate: unavailable (0 install rows)"
      status_line "NEXT" "after a successful tester, record both rows with ./script/record_alpha_success.sh"
      ready=1
    elif [[ "$failure_rate" -lt 30 ]]; then
      status_line "PASS" "install failure rate: ${failure_rate}%"
    else
      status_line "WARN" "install failure rate: ${failure_rate}%"
      status_line "NEXT" "collect more install rows or fix repeated setup blockers"
      ready=1
    fi

    if [[ "$repeated_failures" -eq 0 ]]; then
      status_line "PASS" "no repeated private API failure by macOS version"
    else
      status_line "WARN" "repeated private API failure detected by macOS version"
      ready=1
    fi

    if [[ "$smoke_success" -ge 1 ]]; then
      status_line "PASS" "local install/repair/uninstall smoke pass recorded"
    else
      status_line "WARN" "local install/repair/uninstall smoke pass not recorded"
      status_line "NEXT" "run: ./script/run_local_smoke.sh --apply --full-reset --record"
      ready=1
    fi

    status_line "INFO" "install rows reviewed: $install_rows"
    status_line "INFO" "compatibility rows reviewed: $compatibility_rows"
    status_line "INFO" "local smoke rows reviewed: $smoke_rows"

    if [[ "$ready" -ne 0 ]]; then
      local missing_installs=$(( 5 - install_success ))
      local missing_compatibility=$(( 5 - compatibility_success ))
      local missing_intel=$(( 2 - intel_success ))
      if [[ "$missing_installs" -lt 0 ]]; then missing_installs=0; fi
      if [[ "$missing_compatibility" -lt 0 ]]; then missing_compatibility=0; fi
      if [[ "$missing_intel" -lt 0 ]]; then missing_intel=0; fi

      section "Next evidence packet"
      if [[ "$missing_installs" -gt 0 || "$missing_compatibility" -gt 0 ]]; then
        status_line "NEXT" "record a successful Apple Silicon tester: ./script/record_alpha_success.sh --tester-id tester_XXX --macos-version 15.x --cpu apple_silicon --display-setup built_in"
      fi
      if [[ "$missing_installs" -gt 0 ]]; then
        status_line "NEXT" "missing successful installs with MRR seen: $missing_installs"
      fi
      if [[ "$missing_compatibility" -gt 0 ]]; then
        status_line "NEXT" "missing Lock Screen compatibility passes: $missing_compatibility"
      fi
      if [[ "$EXCLUDE_INTEL" == "true" ]]; then
        status_line "NEXT" "Intel evidence is intentionally excluded from this gate"
      elif [[ "$missing_intel" -gt 0 ]]; then
        status_line "NEXT" "missing Intel compatibility passes if Intel is included: $missing_intel"
        status_line "NEXT" "otherwise keep Intel out of private beta notes"
      fi
      if [[ "$smoke_success" -lt 1 ]]; then
        status_line "NEXT" "missing local smoke pass: 1"
        status_line "NEXT" "preview first: ./script/run_local_smoke.sh"
        status_line "NEXT" "record on clean smoke machine only: ./script/run_local_smoke.sh --apply --full-reset --record"
      fi
    fi
  fi

  section "Signing"
  if signing_ready; then
    status_line "PASS" "Developer ID signing prerequisites appear ready"
  else
    status_line "WARN" "Developer ID signing prerequisites are not ready"
    status_line "NEXT" "run: ./script/signing_preflight.sh"
    ready=1
  fi

  section "Required local smoke"
  status_line "NEXT" "before packaging, run: ./script/check.sh"
  status_line "NEXT" "smoke local install/repair/uninstall: ./script/run_local_smoke.sh --apply --full-reset --record"
  status_line "NEXT" "generate sanitized support report: ./script/support_report.sh"

  if [[ "$ready" -eq 0 ]]; then
    section "Decision"
    status_line "PASS" "private beta packaging evidence is ready"
    status_line "NEXT" "run: ./script/package_private_beta.sh --signed"
  else
    section "Decision"
    status_line "WARN" "private beta packaging evidence is not ready"
  fi

  return "$ready"
}

self_test() {
  local temp_dir ready_output ready_without_intel_output not_ready_output
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-beta-ready.XXXXXX)"
  trap 'rm -rf "$temp_dir"' RETURN

  /bin/mkdir -p "$temp_dir/ready" "$temp_dir/not-ready"
  /bin/mkdir -p "$temp_dir/ready-without-intel"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/install-funnel.csv" "$temp_dir/ready/install-funnel.csv"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/compatibility.csv" "$temp_dir/ready/compatibility.csv"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/local-smoke.csv" "$temp_dir/ready/local-smoke.csv"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/install-funnel.csv" "$temp_dir/ready-without-intel/install-funnel.csv"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/compatibility.csv" "$temp_dir/ready-without-intel/compatibility.csv"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/local-smoke.csv" "$temp_dir/ready-without-intel/local-smoke.csv"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/install-funnel.csv" "$temp_dir/not-ready/install-funnel.csv"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/compatibility.csv" "$temp_dir/not-ready/compatibility.csv"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/local-smoke.csv" "$temp_dir/not-ready/local-smoke.csv"

  for tester in tester_001 tester_002 tester_003 tester_004 tester_005; do
    "$ROOT_DIR/script/record_alpha_install.sh" \
      --tracker-dir "$temp_dir/ready" \
      --tester-id "$tester" \
      --attempt-date 2026-06-08 \
      --stage saw_mrr \
      --build-verify pass \
      --configured-key yes \
      --previewed yes \
      --installed yes \
      --saw-mrr yes \
      --diagnose-summary "PASS summary only" >/dev/null
  done

  for tester in tester_001 tester_002 tester_003 tester_004 tester_005; do
    "$ROOT_DIR/script/record_alpha_install.sh" \
      --tracker-dir "$temp_dir/ready-without-intel" \
      --tester-id "$tester" \
      --attempt-date 2026-06-08 \
      --stage saw_mrr \
      --build-verify pass \
      --configured-key yes \
      --previewed yes \
      --installed yes \
      --saw-mrr yes \
      --diagnose-summary "PASS summary only" >/dev/null
  done

  "$ROOT_DIR/script/record_alpha_compatibility.sh" --tracker-dir "$temp_dir/ready" --tester-id tester_001 --check-date 2026-06-08 --macos-version 15.5 --cpu apple_silicon --display-setup built_in --build-verify pass --preview-glass private --lock-screen-visible yes --unlock-hides-overlay yes --launchagent-stable yes --result pass >/dev/null
  "$ROOT_DIR/script/record_alpha_compatibility.sh" --tracker-dir "$temp_dir/ready" --tester-id tester_002 --check-date 2026-06-08 --macos-version 15.5 --cpu apple_silicon --display-setup external --build-verify pass --preview-glass private --lock-screen-visible yes --unlock-hides-overlay yes --launchagent-stable yes --result pass >/dev/null
  "$ROOT_DIR/script/record_alpha_compatibility.sh" --tracker-dir "$temp_dir/ready" --tester-id tester_003 --check-date 2026-06-08 --macos-version 15.5 --cpu apple_silicon --display-setup multiple --build-verify pass --preview-glass private --lock-screen-visible yes --unlock-hides-overlay yes --launchagent-stable yes --result pass >/dev/null
  "$ROOT_DIR/script/record_alpha_compatibility.sh" --tracker-dir "$temp_dir/ready" --tester-id tester_004 --check-date 2026-06-08 --macos-version 15.5 --cpu intel --display-setup built_in --build-verify pass --preview-glass private --lock-screen-visible yes --unlock-hides-overlay yes --launchagent-stable yes --result pass >/dev/null
  "$ROOT_DIR/script/record_alpha_compatibility.sh" --tracker-dir "$temp_dir/ready" --tester-id tester_005 --check-date 2026-06-08 --macos-version 15.5 --cpu intel --display-setup external --build-verify pass --preview-glass private --lock-screen-visible yes --unlock-hides-overlay yes --launchagent-stable yes --result pass >/dev/null
  "$ROOT_DIR/script/record_alpha_local_smoke.sh" --tracker-dir "$temp_dir/ready" --smoke-date 2026-06-08 --build-verify pass --install-agent pass --diagnose-after-install pass --repair-preserves-data pass --support-report-safe pass --uninstall-all pass --result pass >/dev/null

  "$ROOT_DIR/script/record_alpha_compatibility.sh" --tracker-dir "$temp_dir/ready-without-intel" --tester-id tester_001 --check-date 2026-06-08 --macos-version 15.5 --cpu apple_silicon --display-setup built_in --build-verify pass --preview-glass private --lock-screen-visible yes --unlock-hides-overlay yes --launchagent-stable yes --result pass >/dev/null
  "$ROOT_DIR/script/record_alpha_compatibility.sh" --tracker-dir "$temp_dir/ready-without-intel" --tester-id tester_002 --check-date 2026-06-08 --macos-version 15.5 --cpu apple_silicon --display-setup external --build-verify pass --preview-glass private --lock-screen-visible yes --unlock-hides-overlay yes --launchagent-stable yes --result pass >/dev/null
  "$ROOT_DIR/script/record_alpha_compatibility.sh" --tracker-dir "$temp_dir/ready-without-intel" --tester-id tester_003 --check-date 2026-06-08 --macos-version 15.5 --cpu apple_silicon --display-setup multiple --build-verify pass --preview-glass private --lock-screen-visible yes --unlock-hides-overlay yes --launchagent-stable yes --result pass >/dev/null
  "$ROOT_DIR/script/record_alpha_compatibility.sh" --tracker-dir "$temp_dir/ready-without-intel" --tester-id tester_004 --check-date 2026-06-08 --macos-version 15.5 --cpu apple_silicon --display-setup built_in --build-verify pass --preview-glass private --lock-screen-visible yes --unlock-hides-overlay yes --launchagent-stable yes --result pass >/dev/null
  "$ROOT_DIR/script/record_alpha_compatibility.sh" --tracker-dir "$temp_dir/ready-without-intel" --tester-id tester_005 --check-date 2026-06-08 --macos-version 15.5 --cpu apple_silicon --display-setup external --build-verify pass --preview-glass private --lock-screen-visible yes --unlock-hides-overlay yes --launchagent-stable yes --result pass >/dev/null
  "$ROOT_DIR/script/record_alpha_local_smoke.sh" --tracker-dir "$temp_dir/ready-without-intel" --smoke-date 2026-06-08 --build-verify pass --install-agent pass --diagnose-after-install pass --repair-preserves-data pass --support-report-safe pass --uninstall-all pass --result pass >/dev/null

  ready_output="$(TENKMRR_SIGNING_READY_OVERRIDE=pass "$0" --tracker-dir "$temp_dir/ready" --require-ready)"
  printf '%s\n' "$ready_output" | /usr/bin/grep -q 'private beta packaging evidence is ready'
  printf '%s\n' "$ready_output" | /usr/bin/grep -q 'successful installs with MRR seen: 5/5'
  printf '%s\n' "$ready_output" | /usr/bin/grep -q 'Intel compatibility passes for universal beta: 2/2'
  printf '%s\n' "$ready_output" | /usr/bin/grep -q 'local install/repair/uninstall smoke pass recorded'

  if TENKMRR_SIGNING_READY_OVERRIDE=pass "$0" --tracker-dir "$temp_dir/ready-without-intel" --require-ready >/tmp/10kmrr-beta-ready-without-intel-self-test.$$ 2>&1; then
    printf 'private_beta_readiness self-test failed: Apple Silicon-only tracker passed without --exclude-intel.\n' >&2
    /bin/rm -f /tmp/10kmrr-beta-ready-without-intel-self-test.$$
    exit 1
  fi
  /bin/rm -f /tmp/10kmrr-beta-ready-without-intel-self-test.$$

  ready_without_intel_output="$(TENKMRR_SIGNING_READY_OVERRIDE=pass "$0" --tracker-dir "$temp_dir/ready-without-intel" --exclude-intel --require-ready)"
  printf '%s\n' "$ready_without_intel_output" | /usr/bin/grep -q 'private beta packaging evidence is ready'
  printf '%s\n' "$ready_without_intel_output" | /usr/bin/grep -q 'Intel compatibility excluded from this private beta gate'

  "$ROOT_DIR/script/record_alpha_install.sh" \
    --tracker-dir "$temp_dir/not-ready" \
    --tester-id tester_fail \
    --stage closed_lost \
    --build-verify fail \
    --configured-key no \
    --previewed no \
    --installed no \
    --saw-mrr no \
    --diagnose-summary "WARN summary only" >/dev/null
  "$ROOT_DIR/script/record_alpha_compatibility.sh" --tracker-dir "$temp_dir/not-ready" --tester-id tester_fail_1 --macos-version 15.5 --cpu apple_silicon --display-setup built_in --build-verify pass --preview-glass fail --lock-screen-visible no --unlock-hides-overlay unknown --launchagent-stable yes --result fail >/dev/null
  "$ROOT_DIR/script/record_alpha_compatibility.sh" --tracker-dir "$temp_dir/not-ready" --tester-id tester_fail_2 --macos-version 15.5 --cpu apple_silicon --display-setup external --build-verify pass --preview-glass fail --lock-screen-visible no --unlock-hides-overlay unknown --launchagent-stable yes --result fail >/dev/null

  if TENKMRR_SIGNING_READY_OVERRIDE=pass "$0" --tracker-dir "$temp_dir/not-ready" --require-ready >/tmp/10kmrr-beta-ready-self-test.$$ 2>&1; then
    printf 'private_beta_readiness self-test failed: not-ready tracker passed strict mode.\n' >&2
    /bin/rm -f /tmp/10kmrr-beta-ready-self-test.$$
    exit 1
  fi
  not_ready_output="$(/bin/cat /tmp/10kmrr-beta-ready-self-test.$$)"
  /bin/rm -f /tmp/10kmrr-beta-ready-self-test.$$
  printf '%s\n' "$not_ready_output" | /usr/bin/grep -q 'private beta packaging evidence is not ready'
  printf '%s\n' "$not_ready_output" | /usr/bin/grep -q 'repeated private API failure detected'
  printf '%s\n' "$not_ready_output" | /usr/bin/grep -q 'Next evidence packet'
  printf '%s\n' "$not_ready_output" | /usr/bin/grep -q 'missing successful installs with MRR seen: 5'
  printf '%s\n' "$not_ready_output" | /usr/bin/grep -q './script/record_alpha_success.sh --tester-id tester_XXX'

  if printf '%s\n%s\n%s\n' "$ready_output" "$ready_without_intel_output" "$not_ready_output" | /usr/bin/grep -Eq '(sk_live_|sk_test_|rk_live_|rk_test_|whsec_)'; then
    printf 'private_beta_readiness self-test failed: output contained a secret-like token.\n' >&2
    exit 1
  fi

  printf 'Private beta readiness self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracker-dir)
      if [[ $# -lt 2 || "${2:-}" == --* ]]; then
        usage >&2
        exit 64
      fi
      TRACKER_DIR="$2"
      shift 2
      ;;
    --require-ready)
      REQUIRE_READY=true
      shift
      ;;
    --exclude-intel)
      EXCLUDE_INTEL=true
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

if print_readiness; then
  exit 0
fi

if [[ "$REQUIRE_READY" == "true" ]]; then
  exit 1
fi
