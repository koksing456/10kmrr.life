#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABELS_FILE="$ROOT_DIR/.github/labels.yml"
MODE="dry-run"
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 [--dry-run] [--apply] [--verify] [--self-test] [--help]

Reads .github/labels.yml and prints, verifies, or applies the GitHub issue
label plan. The default is --dry-run. Use --apply only after confirming GitHub
CLI auth.

Options:
  --dry-run    Print label create/update commands without changing GitHub.
  --verify     Verify remote GitHub labels match the local manifest.
  --apply      Apply labels with the gh CLI.
  --self-test  Validate manifest parsing without changing GitHub.
  --help       Show this help.
EOF
}

parse_labels() {
  /usr/bin/awk '
    function emit() {
      if (name != "" && color != "" && description != "") {
        printf "%s\t%s\t%s\n", name, color, description
      }
    }
    /^- name: / {
      emit()
      name = $0
      sub(/^- name: /, "", name)
      gsub(/^"|"$/, "", name)
      color = ""
      description = ""
      next
    }
    /^[[:space:]]*color: / {
      color = $0
      sub(/^[[:space:]]*color: /, "", color)
      gsub(/^"|"$/, "", color)
      next
    }
    /^[[:space:]]*description: / {
      description = $0
      sub(/^[[:space:]]*description: /, "", description)
      gsub(/^"|"$/, "", description)
      next
    }
    END {
      emit()
    }
  ' "$LABELS_FILE"
}

repo_slug() {
  local remote
  remote="$(/usr/bin/git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || true)"
  case "$remote" in
    git@github.com:*)
      printf '%s\n' "${remote#git@github.com:}" | /usr/bin/sed 's/\.git$//'
      ;;
    https://github.com/*)
      printf '%s\n' "${remote#https://github.com/}" | /usr/bin/sed 's/\.git$//'
      ;;
    *)
      printf 'Unable to infer GitHub repo from origin remote: %s\n' "$remote" >&2
      exit 65
      ;;
  esac
}

compare_label_files() {
  local desired_file="$1"
  local actual_file="$2"

  /usr/bin/awk -F '\t' '
    NR == FNR {
      if ($1 != "") {
        desired[$1] = $2 "\t" $3
        desired_count++
      }
      next
    }
    {
      actual[$1] = $2 "\t" $3
    }
    END {
      for (name in desired) {
        if (!(name in actual)) {
          printf "MISSING  %s\n", name
          findings++
        } else if (actual[name] != desired[name]) {
          split(desired[name], d, "\t")
          split(actual[name], a, "\t")
          printf "MISMATCH %s expected color=%s description=%s; got color=%s description=%s\n", name, d[1], d[2], a[1], a[2]
          findings++
        }
      }
      if (findings > 0) {
        exit 1
      }
    }
  ' "$desired_file" "$actual_file"
}

verify_remote_labels() {
  local repo temp_dir desired_file actual_file output count

  if ! command -v gh >/dev/null 2>&1; then
    printf 'GitHub CLI gh is required for --verify. Install gh or rerun with --dry-run.\n' >&2
    exit 69
  fi

  repo="$(repo_slug)"
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-label-verify.XXXXXX)"
  desired_file="$temp_dir/desired.tsv"
  actual_file="$temp_dir/actual.tsv"

  parse_labels >"$desired_file"
  gh label list \
    --repo "$repo" \
    --limit 200 \
    --json name,color,description \
    --jq '.[] | [.name, .color, .description] | @tsv' >"$actual_file"

  printf 'GitHub label sync target: %s\n' "$repo"
  printf 'Mode: verify\n'
  if output="$(compare_label_files "$desired_file" "$actual_file" 2>&1)"; then
    count="$(/usr/bin/awk 'NF > 0 { count++ } END { print count + 0 }' "$desired_file")"
    printf 'PASS  %s manifest labels match GitHub.\n' "$count"
  else
    printf '%s\n' "$output"
    printf 'FAIL  GitHub labels differ from .github/labels.yml. Review with --dry-run, then apply with --apply if correct.\n' >&2
    /bin/rm -rf "$temp_dir"
    exit 1
  fi

  /bin/rm -rf "$temp_dir"
}

self_test() {
  local parsed count temp_dir compare_output
  parsed="$(parse_labels)"
  count="$(printf '%s\n' "$parsed" | /usr/bin/awk 'NF > 0 { count++ } END { print count + 0 }')"

  if [[ "$count" -lt 8 ]]; then
    printf 'Label sync self-test failed: expected at least 8 labels, got %s.\n' "$count" >&2
    exit 1
  fi
  if ! printf '%s\n' "$parsed" | /usr/bin/grep -q $'alpha-request\tc8f6da\t'; then
    printf 'Label sync self-test failed: alpha-request label did not parse correctly.\n' >&2
    exit 1
  fi
  if printf '%s\n' "$parsed" | /usr/bin/awk -F '\t' 'NF != 3 { bad = 1 } END { exit bad }'; then
    :
  else
    printf 'Label sync self-test failed: each parsed label must have name, color, and description.\n' >&2
    exit 1
  fi

  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-label-self-test.XXXXXX)"
  printf 'alpha-request\tc8f6da\tGated alpha access requests that must avoid secrets and private revenue data.\n' >"$temp_dir/desired.tsv"
  printf 'alpha-request\tc8f6da\tGated alpha access requests that must avoid secrets and private revenue data.\n' >"$temp_dir/actual.tsv"
  compare_label_files "$temp_dir/desired.tsv" "$temp_dir/actual.tsv"

  printf 'alpha-request\t000000\tWrong description.\n' >"$temp_dir/actual.tsv"
  if compare_label_files "$temp_dir/desired.tsv" "$temp_dir/actual.tsv" >/dev/null 2>&1; then
    printf 'Label sync self-test failed: mismatch comparison was accepted.\n' >&2
    exit 1
  fi
  compare_output="$(compare_label_files "$temp_dir/desired.tsv" "$temp_dir/actual.tsv" 2>&1 || true)"
  printf '%s\n' "$compare_output" | /usr/bin/grep -q 'MISMATCH alpha-request'
  /bin/rm -rf "$temp_dir"

  printf 'GitHub label sync self-test passed (%s labels).\n' "$count"
}

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      MODE="dry-run"
      ;;
    --verify)
      MODE="verify"
      ;;
    --apply)
      MODE="apply"
      ;;
    --self-test)
      SELF_TEST=true
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

if [[ "$MODE" == "verify" ]]; then
  verify_remote_labels
  exit 0
fi

if [[ "$MODE" == "apply" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    printf 'GitHub CLI gh is required for --apply. Install gh or rerun without --apply for dry-run.\n' >&2
    exit 69
  fi
  REPO="$(repo_slug)"
else
  REPO="$(repo_slug 2>/dev/null || printf 'owner/repo')"
fi

printf 'GitHub label sync target: %s\n' "$REPO"
printf 'Mode: %s\n' "$MODE"

while IFS=$'\t' read -r name color description; do
  [[ -z "${name:-}" ]] && continue
  if [[ "$MODE" == "apply" ]]; then
    printf 'APPLY    %s\n' "$name"
    gh label create "$name" \
      --repo "$REPO" \
      --color "$color" \
      --description "$description" \
      --force
  else
    printf 'DRY-RUN  gh label create %q --repo %q --color %q --description %q --force\n' \
      "$name" "$REPO" "$color" "$description"
  fi
done < <(parse_labels)
