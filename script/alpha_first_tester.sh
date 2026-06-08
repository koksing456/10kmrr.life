#!/usr/bin/env bash
set -euo pipefail

TESTER_ID="tester_XXX"
MACOS_VERSION="15.x"
CPU="apple_silicon"
DISPLAY_SETUP="built_in"

usage() {
  cat <<EOF
Usage: $0 [--tester-id ID] [--macos-version VERSION] [--cpu apple_silicon|intel|unknown] [--display-setup built_in|external|multiple|clamshell|unknown] [--self-test] [--help]

Prints the safe first-tester alpha flow without writing tracker rows.

Use placeholder values for planning. Replace them with real approved tester
evidence before removing --dry-run from invite commands or recording success.

See docs/alpha/first-tester-operator-checklist.md for the operator checklist.
EOF
}

shell_quote() {
  local value="$1"
  printf "'%s'" "${value//\'/\'\\\'\'}"
}

reject_sensitive_value() {
  local label="$1"
  local value="$2"

  if printf '%s\n' "$value" | /usr/bin/grep -Eq '[[:space:]]|[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+|([sr]k_(live|test)_|whsec_)|\b(cus|sub|price|prod|pi|ch|in|cs|pm|seti|si)_[A-Za-z0-9]{8,}\b|[Mm][Rr][Rr][[:space:]:=]+[0-9]'; then
    printf 'Unsafe %s. Use stable non-sensitive planning values only.\n' "$label" >&2
    exit 64
  fi
}

print_flow() {
  local tester_arg macos_arg cpu_arg display_arg
  tester_arg="$(shell_quote "$TESTER_ID")"
  macos_arg="$(shell_quote "$MACOS_VERSION")"
  cpu_arg="$(shell_quote "$CPU")"
  display_arg="$(shell_quote "$DISPLAY_SETUP")"

  cat <<EOF
10kmrr.life first tester flow

Boundary:
RULE  Do not collect Stripe keys, exact MRR, raw logs, raw Stripe responses, customer/payment data, contact data, or unsanitized screenshots.
RULE  Keep tracker rows private under ignored build/alpha-tracker.

Checklist:
READ  docs/alpha/first-tester-operator-checklist.md

1. Refresh private tracker workspace:
RUN   ./script/alpha.sh tracker

2. Preview the invite packet. This writes no evidence:
RUN   ./script/alpha.sh invite --tester-id $tester_arg --macos-version $macos_arg --cpu $cpu_arg --display-setup $display_arg --dry-run

3. Only after a real approved tester exists, remove --dry-run:
RUN   ./script/alpha.sh invite --tester-id $tester_arg --macos-version $macos_arg --cpu $cpu_arg --display-setup $display_arg

4. Ask the tester to run guided setup:
RUN   ./script/alpha.sh start --tester-id $tester_arg

5. If setup works but Lock Screen is not proven yet, record partial install evidence instead of success:
RUN   ./script/alpha.sh install --tester-id $tester_arg --stage saw_mrr --build-verify pass --configured-key yes --previewed yes --installed yes --saw-mrr yes --diagnose-summary 'PASS summary only' --next-action lock_screen_check

6. If Lock Screen is checked separately and the outcome is not a full success packet, record compatibility directly:
RUN   ./script/alpha.sh compatibility --tester-id $tester_arg --macos-version $macos_arg --cpu $cpu_arg --display-setup $display_arg --build-verify pass --preview-glass private --lock-screen-visible yes --unlock-hides-overlay yes --launchagent-stable yes --result pass --next-action day_7_follow_up

7. If all success conditions are manually confirmed, record the safe success packet:
RUN   ./script/alpha.sh success --tester-id $tester_arg --macos-version $macos_arg --cpu $cpu_arg --display-setup $display_arg

8. If anything fails, ask for a sanitized report and record the support issue:
RUN   ./script/alpha.sh support-report
RUN   ./script/alpha.sh support --tester-id $tester_arg --issue-type lock_screen --result fail

9. Schedule Day 7 follow-up after the tester has used it:
RUN   ./script/alpha.sh day7 --tester-id $tester_arg --retained-day-7 yes --overall-pro-signal medium
EOF

  if [[ "$TESTER_ID" == "tester_XXX" || "$MACOS_VERSION" == "15.x" ]]; then
    cat <<EOF

NEXT  Replace tester_XXX and 15.x before writing invite or evidence rows.
NEXT  Keep --dry-run until the tester is real and approved.
EOF
  fi
}

self_test() {
  local output secret_prefix
  output="$("$0")"
  printf '%s\n' "$output" | /usr/bin/grep -q './script/alpha.sh invite'
  printf '%s\n' "$output" | /usr/bin/grep -q -- '--dry-run'
  printf '%s\n' "$output" | /usr/bin/grep -q 'docs/alpha/first-tester-operator-checklist.md'
  printf '%s\n' "$output" | /usr/bin/grep -q -- '--preview-glass private'
  printf '%s\n' "$output" | /usr/bin/grep -q -- '--unlock-hides-overlay yes'
  printf '%s\n' "$output" | /usr/bin/grep -q './script/alpha.sh success'
  printf '%s\n' "$output" | /usr/bin/grep -q 'Replace tester_XXX'
  if printf '%s\n' "$output" | /usr/bin/grep -Eq -- '--install-status|--key-setup-status|--first-mrr-seen|--preview-works|--hides-after-unlock|--private-glass'; then
    printf 'first-tester self-test failed: output contained obsolete alpha command flags.\n' >&2
    exit 1
  fi

  output="$("$0" --tester-id tester_001 --macos-version 15.5 --cpu apple_silicon --display-setup built_in)"
  printf '%s\n' "$output" | /usr/bin/grep -q "./script/alpha.sh start --tester-id 'tester_001'"
  if printf '%s\n' "$output" | /usr/bin/grep -q 'Replace tester_XXX'; then
    printf 'first-tester self-test failed: real-value flow printed placeholder warning.\n' >&2
    exit 1
  fi

  if "$0" --tester-id founder@example.com >/dev/null 2>&1; then
    printf 'first-tester self-test failed: email-like tester id was accepted.\n' >&2
    exit 1
  fi

  secret_prefix="rk_"'live_'
  if "$0" --tester-id "${secret_prefix}1234567890abcdef" >/dev/null 2>&1; then
    printf 'first-tester self-test failed: secret-like tester id was accepted.\n' >&2
    exit 1
  fi

  output="$("$0" --tester-id tester_003 --macos-version 15.5 --cpu apple_silicon --display-setup clamshell)"
  printf '%s\n' "$output" | /usr/bin/grep -q -- "--display-setup 'clamshell'"

  if printf '%s\n' "$output" | /usr/bin/grep -Eq '(sk_live_|sk_test_|rk_live_|rk_test_|whsec_)'; then
    printf 'first-tester self-test failed: output contained a secret-like token.\n' >&2
    exit 1
  fi

  printf 'Alpha first tester flow self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tester-id)
      if [[ $# -lt 2 || "${2:-}" == --* ]]; then
        usage >&2
        exit 64
      fi
      TESTER_ID="$2"
      reject_sensitive_value "--tester-id" "$TESTER_ID"
      shift 2
      ;;
    --macos-version)
      if [[ $# -lt 2 || "${2:-}" == --* ]]; then
        usage >&2
        exit 64
      fi
      MACOS_VERSION="$2"
      reject_sensitive_value "--macos-version" "$MACOS_VERSION"
      shift 2
      ;;
    --cpu)
      if [[ $# -lt 2 || "${2:-}" == --* ]]; then
        usage >&2
        exit 64
      fi
      CPU="$2"
      case "$CPU" in
        apple_silicon|intel|unknown) ;;
        *) usage >&2; exit 64 ;;
      esac
      shift 2
      ;;
    --display-setup)
      if [[ $# -lt 2 || "${2:-}" == --* ]]; then
        usage >&2
        exit 64
      fi
      DISPLAY_SETUP="$2"
      case "$DISPLAY_SETUP" in
        built_in|external|multiple|clamshell|unknown) ;;
        *) usage >&2; exit 64 ;;
      esac
      shift 2
      ;;
    --self-test)
      self_test
      exit 0
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

print_flow
