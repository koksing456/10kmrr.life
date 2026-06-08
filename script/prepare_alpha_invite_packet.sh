#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKER_DIR="$ROOT_DIR/build/alpha-tracker"
OUTPUT_DIR="$ROOT_DIR/build/alpha-invites"
TESTER_ID=""
USES_STRIPE_SUBSCRIPTIONS="yes"
MACOS_VERSION="unknown"
CPU="unknown"
DISPLAY_SETUP="unknown"
FORCE=false
SELF_TEST=false
DRY_RUN=false

usage() {
  cat <<EOF
Usage: $0 --tester-id ID [options]

Prepares a private alpha invite packet:
  1. Records an approved tester row in the private ignored tracker.
  2. Writes a safe invite message to build/alpha-invites/ID.md.
  3. Prints the next setup command.

The invite file is generated under build/, which is ignored by git. Keep
identity/contact mapping outside this repo.

Options:
  --tracker-dir DIR                Tracker directory. Default: build/alpha-tracker.
  --output-dir DIR                 Invite output directory. Default: build/alpha-invites.
  --tester-id ID                   Required stable private tester id.
  --uses-stripe-subscriptions VAL  yes|no|unknown. Default: yes.
  --macos-version VALUE            Non-sensitive version summary, for example 15.5.
  --cpu VALUE                      apple_silicon|intel|unknown.
  --display-setup VALUE            built_in|external|multiple|unknown.
  --force                          Allow rewriting an existing invite file and appending another row.
  --dry-run                        Print the safe packet without writing tracker rows or invite files.
  --self-test                      Verify wrapper behavior in a temporary tracker.
  --help                           Show this help.
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

validate_tester_id() {
  local value="$1"

  if [[ -z "$value" ]]; then
    printf 'Missing required --tester-id.\n' >&2
    exit 64
  fi

  if printf '%s\n' "$value" | /usr/bin/grep -Eq '[[:space:]]|[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+|([sr]k_(live|test)_|whsec_)|\b(cus|sub|price|prod|pi|ch|in|cs|pm|seti|si)_[A-Za-z0-9]{8,}\b|([Mm][Rr][Rr]|[Aa][Rr][Rr]|[Rr]evenue|[Aa]mount)[[:space:]:=]+[0-9]'; then
    printf 'Unsafe --tester-id. Use a stable private id like tester_001, not contact data, secrets, Stripe ids, or revenue values.\n' >&2
    exit 64
  fi
}

validate_choice() {
  local label="$1"
  local value="$2"
  local allowed="$3"

  if ! printf '%s\n' "$allowed" | /usr/bin/grep -Fxq "$value"; then
    printf 'Invalid %s: %s\nAllowed values:\n%s\n' "$label" "$value" "$allowed" >&2
    exit 64
  fi
}

validate_write_values() {
  if printf '%s\n%s\n' "$TESTER_ID" "$MACOS_VERSION" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(tester_XXX|tester_xxx|15\.x|x\.x)([^[:alnum:]_]|$)'; then
    printf 'Invite write mode needs real evidence values. Replace tester_XXX and 15.x placeholders, or use --dry-run to preview without writing.\n' >&2
    exit 64
  fi
}

has_placeholder_values() {
  printf '%s\n%s\n' "$TESTER_ID" "$MACOS_VERSION" | /usr/bin/grep -Eiq '(^|[^[:alnum:]_])(tester_XXX|tester_xxx|15\.x|x\.x)([^[:alnum:]_]|$)'
}

ensure_tracker() {
  if [[ ! -s "$TRACKER_DIR/alpha-users.csv" ]]; then
    printf 'Alpha users tracker missing. Run ./script/alpha.sh tracker first.\n' >&2
    exit 1
  fi
}

tester_already_tracked() {
  local file="$TRACKER_DIR/alpha-users.csv"
  [[ -f "$file" ]] || return 1

  /usr/bin/awk -v tester_id="$TESTER_ID" '
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
    NR > 1 && csvfield($0, 1) == tester_id { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$file"
}

assert_invite_safe() {
  local file="$1"

  if /usr/bin/grep -Eq '(sk_live_|sk_test_|rk_live_|rk_test_|whsec_)' "$file"; then
    printf 'Invite packet contains a secret-like token: %s\n' "$file" >&2
    return 1
  fi

  if /usr/bin/grep -Eq '[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+' "$file"; then
    printf 'Invite packet contains email-like contact data: %s\n' "$file" >&2
    return 1
  fi

  if /usr/bin/grep -Eq '\b(cus|sub|price|prod|pi|ch|in|cs|pm|seti|si)_[A-Za-z0-9]{8,}\b|client_secret|hosted_invoice_url|invoice_pdf|payment_method|customer_email' "$file"; then
    printf 'Invite packet contains Stripe object or raw Stripe field: %s\n' "$file" >&2
    return 1
  fi
}

render_invite_packet() {
  local target_file="$1"
  {
    printf '# 10kmrr.life Alpha Invite Packet\n\n'
    printf '%s\n' "- Tester id: \`$TESTER_ID\`"
    printf '%s\n' "- macOS version: \`$MACOS_VERSION\`"
    printf '%s\n' "- CPU: \`$CPU\`"
    printf '%s\n\n' "- Display setup: \`$DISPLAY_SETUP\`"
    "$ROOT_DIR/script/generate_alpha_invite.sh" --tester-id "$TESTER_ID"
    printf '\n\n## Operator Next Steps\n\n'
    printf 'After the tester reports success, record:\n\n'
    printf '```sh\n'
    printf './script/alpha.sh success \\\n'
    printf '  --tester-id %s \\\n' "$(shell_quote "$TESTER_ID")"
    printf '  --macos-version %s \\\n' "$(shell_quote "$MACOS_VERSION")"
    printf '  --cpu %s \\\n' "$(shell_quote "$CPU")"
    printf '  --display-setup %s\n' "$(shell_quote "$DISPLAY_SETUP")"
    printf '```\n\n'
    printf 'If setup fails, record a safe support issue instead:\n\n'
    printf '```sh\n'
    printf './script/alpha.sh support --tester-id %s --issue-type lock_screen --result fail\n' "$(shell_quote "$TESTER_ID")"
    printf '```\n'
  } >"$target_file"
}

write_invite_packet() {
  local output_file="$1"
  local temp_file

  /bin/mkdir -p "$OUTPUT_DIR"
  temp_file="$(/usr/bin/mktemp -t 10kmrr-alpha-invite.XXXXXX)"

  render_invite_packet "$temp_file"
  assert_invite_safe "$temp_file"
  /bin/mv "$temp_file" "$output_file"
}

dry_run_packet() {
  local temp_file
  temp_file="$(/usr/bin/mktemp -t 10kmrr-alpha-invite-dry-run.XXXXXX)"

  validate_tester_id "$TESTER_ID"
  validate_choice "uses Stripe subscriptions" "$USES_STRIPE_SUBSCRIPTIONS" $'yes\nno\nunknown'
  validate_choice "cpu" "$CPU" $'apple_silicon\nintel\nunknown'
  validate_choice "display setup" "$DISPLAY_SETUP" $'built_in\nexternal\nmultiple\nunknown'

  render_invite_packet "$temp_file"
  assert_invite_safe "$temp_file"

  printf 'DRY RUN: no tracker row or invite file was written.\n'
  if has_placeholder_values; then
    printf 'TEMPLATE ONLY: replace tester_XXX and 15.x before sending this packet or recording evidence.\n'
    printf 'Do not send this placeholder packet to a tester.\n'
  fi
  printf '\n'
  /bin/cat "$temp_file"
  /bin/rm -f "$temp_file"
}

prepare_packet() {
  local output_file

  validate_tester_id "$TESTER_ID"
  validate_choice "uses Stripe subscriptions" "$USES_STRIPE_SUBSCRIPTIONS" $'yes\nno\nunknown'
  validate_choice "cpu" "$CPU" $'apple_silicon\nintel\nunknown'
  validate_choice "display setup" "$DISPLAY_SETUP" $'built_in\nexternal\nmultiple\nunknown'

  if [[ "$DRY_RUN" == "true" ]]; then
    dry_run_packet
    return
  fi

  validate_write_values
  ensure_tracker

  output_file="$OUTPUT_DIR/$TESTER_ID.md"
  if [[ "$FORCE" != "true" ]]; then
    if tester_already_tracked; then
      printf 'Tester id already exists in alpha-users tracker: %s\n' "$TESTER_ID" >&2
      printf 'Use --force only if you intentionally want another private row.\n' >&2
      exit 1
    fi
    if [[ -f "$output_file" ]]; then
      printf 'Invite packet already exists: %s\n' "$output_file" >&2
      printf 'Use --force to rewrite it.\n' >&2
      exit 1
    fi
  fi

  "$ROOT_DIR/script/approve_alpha_tester.sh" \
    --tracker-dir "$TRACKER_DIR" \
    --tester-id "$TESTER_ID" \
    --uses-stripe-subscriptions "$USES_STRIPE_SUBSCRIPTIONS" \
    --macos-version "$MACOS_VERSION" \
    --cpu "$CPU" \
    --display-setup "$DISPLAY_SETUP" >/dev/null

  write_invite_packet "$output_file"

  printf 'Prepared safe alpha invite packet: %s\n' "$output_file"
  printf 'Send the invite body from that file to the approved tester.\n'
  printf 'Next tester command: ./script/alpha.sh start --tester-id %s\n' "$(shell_quote "$TESTER_ID")"
}

self_test() {
  local temp_dir output live_env
  live_env="live"
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-alpha-invite-packet.XXXXXX)"
  trap 'rm -rf "$temp_dir"' RETURN

  /bin/mkdir -p "$temp_dir/tracker"
  /bin/cp "$ROOT_DIR/docs/alpha/templates/alpha-users.csv" "$temp_dir/tracker/alpha-users.csv"

  output="$("$0" \
    --tracker-dir "$temp_dir/tracker" \
    --output-dir "$temp_dir/invites" \
    --tester-id tester_001 \
    --macos-version 15.5 \
    --cpu apple_silicon \
    --display-setup built_in)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'Prepared safe alpha invite packet'
  test -s "$temp_dir/invites/tester_001.md"
  /usr/bin/grep -q './script/alpha.sh start --tester-id tester_001' "$temp_dir/invites/tester_001.md"
  /usr/bin/grep -q './script/alpha.sh success' "$temp_dir/invites/tester_001.md"
  /usr/bin/grep -q './script/alpha.sh support' "$temp_dir/invites/tester_001.md"
  /usr/bin/grep -q 'safe reply format' "$temp_dir/invites/tester_001.md"
  /usr/bin/grep -q 'Do not include exact MRR' "$temp_dir/invites/tester_001.md"
  /usr/bin/tail -1 "$temp_dir/tracker/alpha-users.csv" | /usr/bin/grep -q '"tester_001","yes","15.5","apple_silicon","built_in","yes","approved"'

  output="$("$0" \
    --tracker-dir "$temp_dir/tracker" \
    --output-dir "$temp_dir/dry-run-invites" \
    --tester-id tester_002 \
    --macos-version 15.5 \
    --cpu apple_silicon \
    --display-setup built_in \
    --dry-run)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'DRY RUN: no tracker row or invite file was written'
  printf '%s\n' "$output" | /usr/bin/grep -q '# 10kmrr.life Alpha Invite Packet'
  if printf '%s\n' "$output" | /usr/bin/grep -q 'TEMPLATE ONLY'; then
    printf 'prepare_alpha_invite_packet self-test failed: real-value dry-run printed placeholder warning.\n' >&2
    exit 1
  fi
  test ! -e "$temp_dir/dry-run-invites/tester_002.md"
  if /usr/bin/grep -q '"tester_002"' "$temp_dir/tracker/alpha-users.csv"; then
    printf 'prepare_alpha_invite_packet self-test failed: dry-run wrote a tracker row.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --output-dir "$temp_dir/invites" --tester-id tester_001 >/dev/null 2>&1; then
    printf 'prepare_alpha_invite_packet self-test failed: duplicate tester id was accepted without --force.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --output-dir "$temp_dir/invites" --tester-id 'founder@example.com' >/dev/null 2>&1; then
    printf 'prepare_alpha_invite_packet self-test failed: email-like tester id was accepted.\n' >&2
    exit 1
  fi

  output="$("$0" \
    --tracker-dir "$temp_dir/tracker" \
    --output-dir "$temp_dir/placeholder-dry-run" \
    --tester-id tester_XXX \
    --macos-version 15.x \
    --cpu apple_silicon \
    --display-setup built_in \
    --dry-run)"
  printf '%s\n' "$output" | /usr/bin/grep -q 'DRY RUN: no tracker row or invite file was written'
  printf '%s\n' "$output" | /usr/bin/grep -q 'TEMPLATE ONLY: replace tester_XXX and 15.x before sending this packet or recording evidence'
  printf '%s\n' "$output" | /usr/bin/grep -q 'Do not send this placeholder packet to a tester'

  if "$0" \
    --tracker-dir "$temp_dir/tracker" \
    --output-dir "$temp_dir/invites" \
    --tester-id tester_XXX \
    --macos-version 15.5 \
    --cpu apple_silicon \
    --display-setup built_in >/dev/null 2>&1; then
    printf 'prepare_alpha_invite_packet self-test failed: placeholder tester id was accepted in write mode.\n' >&2
    exit 1
  fi

  if "$0" \
    --tracker-dir "$temp_dir/tracker" \
    --output-dir "$temp_dir/invites" \
    --tester-id tester_005 \
    --macos-version 15.x \
    --cpu apple_silicon \
    --display-setup built_in >/dev/null 2>&1; then
    printf 'prepare_alpha_invite_packet self-test failed: placeholder macOS version was accepted in write mode.\n' >&2
    exit 1
  fi

  if "$0" --tracker-dir "$temp_dir/tracker" --output-dir "$temp_dir/invites" --tester-id "rk_${live_env}_1234567890abcdef" >/dev/null 2>&1; then
    printf 'prepare_alpha_invite_packet self-test failed: secret-like tester id was accepted.\n' >&2
    exit 1
  fi

  if /usr/bin/grep -R -E "(sk_live_|sk_test_|rk_${live_env}_|rk_test_|whsec_|founder@example\\.com)" "$temp_dir/invites" >/dev/null; then
    printf 'prepare_alpha_invite_packet self-test failed: invite output contained sensitive-looking data.\n' >&2
    exit 1
  fi

  printf 'Alpha invite packet self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracker-dir) require_arg "$1" "${2:-}"; TRACKER_DIR="$2"; shift 2 ;;
    --output-dir) require_arg "$1" "${2:-}"; OUTPUT_DIR="$2"; shift 2 ;;
    --tester-id) require_arg "$1" "${2:-}"; TESTER_ID="$2"; shift 2 ;;
    --uses-stripe-subscriptions) require_arg "$1" "${2:-}"; USES_STRIPE_SUBSCRIPTIONS="$2"; shift 2 ;;
    --macos-version) require_arg "$1" "${2:-}"; MACOS_VERSION="$2"; shift 2 ;;
    --cpu) require_arg "$1" "${2:-}"; CPU="$2"; shift 2 ;;
    --display-setup) require_arg "$1" "${2:-}"; DISPLAY_SETUP="$2"; shift 2 ;;
    --force) FORCE=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --self-test) SELF_TEST=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
done

if [[ "$SELF_TEST" == "true" ]]; then
  self_test
  exit 0
fi

prepare_packet
