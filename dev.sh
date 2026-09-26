#!/usr/bin/env bash
#
# Starts the Devlane development stack: Go API (:8080) and Vite web app (:5173).
#
# Runs preflight checks first (toolchain, database reachability, .env, node_modules),
# then launches both apps in parallel. Ctrl+C stops both.
#
# Usage:
#   ./dev.sh            # start both apps
#   ./dev.sh api        # start only the API
#   ./dev.sh web        # start only the web app

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$ROOT/apps/api"
WEB_DIR="$ROOT/apps/web"
TARGET="${1:-all}"

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'
RESET=$'\033[0m'

info() { printf '%s==>%s %s\n' "$BLUE" "$RESET" "$1"; }
ok() { printf '%s  ok%s %s\n' "$GREEN" "$RESET" "$1"; }
warn() { printf '%s warn%s %s\n' "$YELLOW" "$RESET" "$1"; }
fail() {
  printf '%serror%s %s\n' "$RED" "$RESET" "$1" >&2
  exit 1
}

# Reads a key from apps/api/.env, ignoring comments. Falls back to $2.
env_value() {
  local key="$1" fallback="${2:-}" value=""
  if [ -f "$API_DIR/.env" ]; then
    value="$(grep -E "^[[:space:]]*$key=" "$API_DIR/.env" | tail -n 1 | cut -d= -f2- | tr -d '[:space:]')"
  fi
  printf '%s' "${value:-$fallback}"
}

preflight_api() {
  command -v go >/dev/null 2>&1 || fail "go not found. Install it with: brew install go"

  if [ ! -f "$API_DIR/.env" ]; then
    if [ -f "$API_DIR/.env.example" ]; then
      cp "$API_DIR/.env.example" "$API_DIR/.env"
      warn "apps/api/.env was missing; created it from .env.example."
      warn "DB_PORT defaults to 15432 (docker compose). Using a local Postgres? Set it to 5432."
    else
      fail "apps/api/.env and apps/api/.env.example are both missing."
    fi
  fi

  local host port
  host="$(env_value DB_HOST localhost)"
  port="$(env_value DB_PORT 5432)"

  if ! nc -z "$host" "$port" >/dev/null 2>&1; then
    printf '%serror%s Postgres is not reachable at %s:%s.\n\n' "$RED" "$RESET" "$host" "$port" >&2
    printf 'Start it one of these ways, then re-run this script:\n\n' >&2
    printf '  Docker:          docker compose up -d\n' >&2
    printf '                   (exposes Postgres on host port 15432)\n\n' >&2
    printf '  Local Postgres:  brew services start postgresql@16\n' >&2
    printf '                   (listens on 5432)\n\n' >&2
    printf 'Then make sure DB_PORT in apps/api/.env matches the port above.\n' >&2
    exit 1
  fi
  ok "Postgres reachable at $host:$port"
}

preflight_web() {
  command -v npm >/dev/null 2>&1 || fail "npm not found. Install Node.js first."

  if [ ! -d "$WEB_DIR/node_modules" ]; then
    info "Installing web dependencies (first run)…"
    npm --prefix "$WEB_DIR" install
  fi
  ok "Web dependencies present"
}

start_api() {
  info "API starting on http://localhost:$(env_value SERVER_PORT 8080)"
  (cd "$API_DIR" && go run ./cmd/api) &
  API_PID=$!
}

start_web() {
  info "Web starting on http://localhost:5173"
  npm --prefix "$WEB_DIR" run dev &
  WEB_PID=$!
}

# Kills the whole process group of each child so `go run` and vite subprocesses
# do not survive Ctrl+C.
cleanup() {
  trap - INT TERM EXIT
  info "Shutting down…"
  for pid in "${API_PID:-}" "${WEB_PID:-}"; do
    [ -n "$pid" ] && kill -- "-$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
}

trap cleanup INT TERM EXIT
set -m # own process group per child, so cleanup can kill the whole tree

case "$TARGET" in
api)
  preflight_api
  start_api
  ;;
web)
  preflight_web
  start_web
  ;;
all)
  preflight_api
  preflight_web
  start_api
  start_web
  ;;
*)
  fail "Unknown target '$TARGET'. Use: all (default), api, or web."
  ;;
esac

printf '\n'
info "Running. Press Ctrl+C to stop."
printf '\n'

wait
