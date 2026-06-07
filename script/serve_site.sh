#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-4173}"

printf 'Serving 10kmrr.life static alpha page at http://127.0.0.1:%s\n' "$PORT"
python3 -m http.server "$PORT" --directory "$ROOT_DIR/site"
