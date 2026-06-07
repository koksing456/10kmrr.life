#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABELS_FILE="$ROOT_DIR/.github/labels.yml"
APPLY=false
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 [--dry-run] [--apply] [--self-test] [--help]

Reads .github/labels.yml and prints or applies the GitHub issue label plan.
The default is --dry-run. Use --apply only after confirming GitHub CLI auth.

Options:
  --dry-run    Print label create/update commands without changing GitHub.
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

self_test() {
  local parsed count
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

  printf 'GitHub label sync self-test passed (%s labels).\n' "$count"
}

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      APPLY=false
      ;;
    --apply)
      APPLY=true
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

if [[ "$APPLY" == "true" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    printf 'GitHub CLI gh is required for --apply. Install gh or rerun without --apply for dry-run.\n' >&2
    exit 69
  fi
  REPO="$(repo_slug)"
else
  REPO="$(repo_slug 2>/dev/null || printf 'owner/repo')"
fi

printf 'GitHub label sync target: %s\n' "$REPO"
printf 'Mode: %s\n' "$([[ "$APPLY" == "true" ]] && printf apply || printf dry-run)"

while IFS=$'\t' read -r name color description; do
  [[ -z "${name:-}" ]] && continue
  if [[ "$APPLY" == "true" ]]; then
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
