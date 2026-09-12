#!/usr/bin/env bash
# School Connect — one-command startup (development).
#
# Brings up:
#  1. The Frappe bench for the school site (Sunrise / library.localhost) on :8000
#  2. The super-admin registry site on :8002
#  3. The school-admin web dashboard (React + Vite) on :5173
#
# The Flutter mobile app is started separately with `flutter run` because it
# needs a connected device/emulator. See the printed instructions.
#
# Prerequisites (one-time):
#  - MariaDB running (brew services start mariadb, or equivalent)
#  - ~/Documents/frappe/frappe-bench exists and is healthy
#  - node + npm available for the web admin
#
# Environment: you can override the bench dir and site with
#   FRAPPE_BENCH_DIR  (default ~/Documents/frappe/frappe-bench)
#   FRAPPE_SITE       (default library.localhost)
#   FRAPPE_SUPER_SITE (default superadmin.localhost)
#
# Usage:
#   ./start.sh          # start backend + web admin in the background
#   ./start.sh --wait   # like above, but print a blocking "press Ctrl-C to stop"
#   ./start.sh --help   # this message

set -euo pipefail

BENCH_DIR="${FRAPPE_BENCH_DIR:-"$HOME/Documents/frappe/frappe-bench"}"
SITE="${FRAPPE_SITE:-library.localhost}"
SUPER_SITE="${FRAPPE_SUPER_SITE:-superadmin.localhost}"
SCHOOL_PORT=8000
SUPER_PORT=8002
WEB_ADMIN_DIR="$(pwd)/schooladmin"
WEB_ADMIN_PORT=5173

print_usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Bring up the School Connect development stack.

Options:
  --help        Show this message
  --wait        Start services and block until Ctrl-C (useful for one-terminal dev)
  --no-web      Skip the web admin dashboard
  --status      Print whether the expected services are reachable

Environment:
  FRAPPE_BENCH_DIR   Bench directory (default: $BENCH_DIR)
  FRAPPE_SITE        School site (default: $SITE)
  FRAPPE_SUPER_SITE  Super-admin site (default: $SUPER_SITE)

Flutter mobile app (separate):
  cd school_connect_app && flutter run -d macos
  (or any device) — it talks to $SCHOOL_PORT by default.

Stop everything:
  kill the bench processes (bench serve) and the Vite server; this script
  leaves them running in the background so you can close the terminal.
EOF
}

check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: $1 is required but not found on PATH."
    return 1
  fi
}

print_status() {
  echo "Checking connectivity..."
  local ok=true

  if curl -sSf --max-time 5 "http://localhost:$SCHOOL_PORT/api/method/ping" >/dev/null 2>&1; then
    echo "  ✅ School bench (:$SCHOOL_PORT) — ping ok"
  else
    echo "  ❌ School bench (:$SCHOOL_PORT) — not reachable"
    ok=false
  fi

  if curl -sSf --max-time 5 "http://localhost:$SUPER_PORT/api/method/ping" >/dev/null 2>&1; then
    echo "  ✅ Super-admin bench (:$SUPER_PORT) — ping ok"
  else
    echo "  ❌ Super-admin bench (:$SUPER_PORT) — not reachable"
    ok=false
  fi

  if curl -sSf --max-time 5 "http://localhost:$WEB_ADMIN_PORT" >/dev/null 2>&1; then
    echo "  ✅ Web admin (:$WEB_ADMIN_PORT) — reachable"
  else
    echo "  ❌ Web admin (:$WEB_ADMIN_PORT) — not reachable"
    ok=false
  fi

  if $ok; then
    echo "All services are up."
  else
    echo "Some services are down — run $(basename "$0") without --status to start them."
  fi
}

start_bench() {
  local site="$1"
  local port="$2"
  local label="$3"

  if ! pgrep -f "bench serve.*--site $site" >/dev/null 2>&1; then
    echo "Starting $label on :$port ($site)..."
    (cd "$BENCH_DIR" && bench serve --port "$port" --site "$site") >/dev/null 2>&1 &
    disown
  else
    echo "$label on :$port is already running."
  fi
}

wait_for_bench() {
  local port="$1"
  local label="$2"
  local max=60
  local i=0
  echo "Waiting for $label (:$port)..."
  while (( i++ < max )); do
    if curl -sSf --max-time 2 "http://localhost:$port/api/method/ping" >/dev/null 2>&1; then
      echo "$label is up (:$port)."
      return 0
    fi
    sleep 1
  done
  echo "WARNING: $label did not become healthy within ${max}s." >&2
  return 1
}

start_web_admin() {
  if [[ ! -d "$WEB_ADMIN_DIR" ]]; then
    echo "WARNING: schooladmin/ not found at $WEB_ADMIN_DIR — skipping web admin."
    return
  fi
  if pgrep -f "vite" >/dev/null 2>&1; then
    echo "Web admin seems to already be running (vite process found)."
    return
  fi
  echo "Starting web admin (schooladmin) on :$WEB_ADMIN_PORT..."
  (cd "$WEB_ADMIN_DIR" && npm run dev) >/dev/null 2>&1 &
  disown
}

wait_for_web_admin() {
  local max=40
  local i=0
  echo "Waiting for web admin (:$WEB_ADMIN_PORT)..."
  while (( i++ < max )); do
    if curl -sSf --max-time 2 "http://localhost:$WEB_ADMIN_PORT" >/dev/null 2>&1; then
      echo "Web admin is up (:$WEB_ADMIN_PORT)."
      return 0
    fi
    sleep 1
  done
  echo "WARNING: web admin did not become healthy within ${max}s." >&2
  return 1
}

main() {
  local mode=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help) print_usage; exit 0 ;;
      --wait) mode="wait" ;;
      --no-web) mode="${mode} no-web" ;;
      --status) print_status; exit 0 ;;
      *) echo "Unknown option: $1" >&2; print_usage >&2; exit 1 ;;
    esac
    shift
  done

  check_command curl || exit 1

  echo "=== School Connect development startup ==="
  echo "Bench dir : $BENCH_DIR"
  echo "School site: $SITE (:${SCHOOL_PORT})"
  echo "Super site : $SUPER_SITE (:${SUPER_PORT})"
  echo ""

  if [[ ! -d "$BENCH_DIR" ]]; then
    echo "ERROR: Frappe bench not found at $BENCH_DIR."
    echo "Set FRAPPE_BENCH_DIR to the correct path, or create the bench first."
    exit 1
  fi

  # Start school site bench (idempotent)
  start_bench "$SITE" "$SCHOOL_PORT" "School bench"
  start_bench "$SUPER_SITE" "$SUPER_PORT" "Super-admin bench"

  # Wait for them to be healthy
  wait_for_bench "$SCHOOL_PORT" "School bench" || true
  wait_for_bench "$SUPER_PORT" "Super-admin bench" || true

  # Web admin
  if [[ "$mode" != *no-web* ]]; then
    start_web_admin
    wait_for_web_admin || true
  fi

  echo ""
  echo "=== Services ==="
  echo "School bench    : http://localhost:$SCHOOL_PORT"
  echo "Super-admin     : http://localhost:$SUPER_PORT"
  [[ "$mode" != *no-web* ]] && echo "Web admin       : http://localhost:$WEB_ADMIN_PORT"
  echo ""
  echo "Flutter mobile app (start in another terminal):"
  echo "  cd school_connect_app && flutter run -d macos"
  echo ""
  echo "Quick test accounts (school site :$SCHOOL_PORT):"
  echo "  Teacher  : robert.johnson@school.com / Teacher@123"
  echo "  Student  : alex.smith@school.com / Student@123"
  echo "  School Admin: sunrise.admin@school.com / Admin@12345"
  echo ""
  echo "Super-admin account (:${SUPER_PORT}):"
  echo "  super.admin@school.com / Super@12345"
  echo ""

  if [[ "$mode" == *wait* ]]; then
    echo "Press Ctrl-C to stop (services are backgrounded; this terminal stays open)."
    wait
  fi
}

main "$@"
