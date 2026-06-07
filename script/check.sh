#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<EOF
Usage: $0 [--help]

Runs the public-alpha repository verification gate, then prints signing and
notarization readiness without printing credentials.
EOF
}

case "${1:-}" in
  --help|-h)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac

cd "$ROOT_DIR"

printf 'Running 10kmrr.life public-alpha checks...\n'
./script/verify_public_repo.sh

printf '\nChecking signing readiness...\n'
./script/signing_preflight.sh

printf '\nCheck complete.\n'
