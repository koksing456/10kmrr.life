#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-4173}"
SELF_TEST=false

usage() {
  cat <<EOF
Usage: $0 [--self-test] [--help]

Serves the static public-alpha page from site/.

Options:
  --self-test  Verify port-conflict handling without serving the site.
  --help       Show this help.
EOF
}

port_responds() {
  /usr/bin/curl -fsS "http://127.0.0.1:$PORT" >/dev/null 2>&1
}

run_server() {
  if ! command -v python3 >/dev/null 2>&1; then
    printf 'python3 is required to serve the static alpha page.\n' >&2
    exit 69
  fi

  if port_responds; then
    printf 'Port %s already responds on 127.0.0.1. Stop that server or set PORT to a free port.\n' "$PORT" >&2
    exit 69
  fi

  printf 'Serving 10kmrr.life static alpha page at http://127.0.0.1:%s\n' "$PORT"
  exec python3 -m http.server "$PORT" --directory "$ROOT_DIR/site"
}

self_test() {
  local temp_dir port_file server_pid output
  temp_dir="$(/usr/bin/mktemp -d -t 10kmrr-serve-site.XXXXXX)"
  port_file="$temp_dir/port"
  cleanup_self_test() {
    if [[ -n "${server_pid:-}" ]]; then
      kill "$server_pid" 2>/dev/null || true
      wait "$server_pid" 2>/dev/null || true
    fi
    rm -rf "$temp_dir"
  }
  trap cleanup_self_test RETURN

  python3 - "$port_file" <<'PY' &
import http.server
import socketserver
import sys

port_file = sys.argv[1]

class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

with socketserver.TCPServer(("127.0.0.1", 0), QuietHandler) as httpd:
    with open(port_file, "w", encoding="utf-8") as handle:
        handle.write(str(httpd.server_address[1]))
    httpd.serve_forever()
PY
  server_pid="$!"

  for _ in $(seq 1 40); do
    [[ -s "$port_file" ]] && break
    sleep 0.1
  done

  if [[ ! -s "$port_file" ]]; then
    printf 'serve_site self-test failed: temporary server did not report a port.\n' >&2
    exit 1
  fi

  PORT="$(/bin/cat "$port_file")"
  if output="$(PORT="$PORT" "$0" 2>&1)"; then
    printf 'serve_site self-test failed: occupied port was accepted.\n' >&2
    exit 1
  fi

  printf '%s\n' "$output" | /usr/bin/grep -q 'already responds'
  printf 'Static site server self-test passed.\n'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

if [[ "$SELF_TEST" == "true" ]]; then
  self_test
  exit 0
fi

run_server
