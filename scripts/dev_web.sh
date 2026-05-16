#!/usr/bin/env bash
# Warehouse Sort dev loop: serve the game on localhost:8765 with a FIFO
# so we can issue hot-reload (`r`) and hot-restart (`R`) commands from
# another shell or from automation.
#
# Usage:
#   bash scripts/dev_web.sh start    # starts the server in the background
#   bash scripts/dev_web.sh reload   # hot reload (state-preserving)
#   bash scripts/dev_web.sh restart  # hot restart (rebuilds app)
#   bash scripts/dev_web.sh logs     # tail the server log
#   bash scripts/dev_web.sh stop     # kill the server
#   bash scripts/dev_web.sh status   # check if running
#
# The server runs in debug mode (so hot reload works) and listens on
# 127.0.0.1:8765. AdMob and IAP services are no-ops on web.

set -euo pipefail

# SORTBLOOM_PORT honoured for backward compatibility with any scripts
# that already export it; new override env is WH_SORT_PORT.
PORT=${WH_SORT_PORT:-${SORTBLOOM_PORT:-8765}}
FIFO=/tmp/wh-sort-flutter-fifo
LOG=/tmp/wh-sort-flutter.log
PIDFILE=/tmp/wh-sort-flutter.pid
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cmd=${1:-start}

start() {
  if [[ -f $PIDFILE ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Already running (pid $(cat "$PIDFILE")). Use 'restart' to recreate."
    return 0
  fi
  rm -f "$FIFO" "$LOG"
  mkfifo "$FIFO"
  cd "$REPO_DIR"
  # Hold the FIFO open from this shell so flutter doesn't get EOF immediately.
  # We background a sleep that holds the write side.
  # `sleep infinity` isn't portable; macOS sleep needs a number.
  ( exec 3>"$FIFO"; sleep 2147483 >&3 ) &
  HOLDER=$!
  echo "$HOLDER" >/tmp/wh-sort-fifo-holder.pid
  ( flutter run -d web-server --web-port "$PORT" --web-hostname 127.0.0.1 \
      <"$FIFO" >"$LOG" 2>&1 ) &
  echo $! >"$PIDFILE"
  echo "Starting flutter web server on http://127.0.0.1:$PORT (pid $(cat "$PIDFILE"))"
  echo "Watching log; first compile takes ~15s"
  for _ in $(seq 1 60); do
    if grep -q "is being served at" "$LOG" 2>/dev/null; then
      echo "Server is up."
      tail -3 "$LOG"
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for server. Tail of log:"
  tail -30 "$LOG" || true
  return 1
}

reload() {
  [[ -p $FIFO ]] || { echo "FIFO missing; is the server running?"; exit 1; }
  printf 'r' >"$FIFO"
  echo "Hot reload sent."
}

restart() {
  [[ -p $FIFO ]] || { start; return; }
  printf 'R' >"$FIFO"
  echo "Hot restart sent."
}

logs() {
  exec tail -n 200 -f "$LOG"
}

stop() {
  if [[ -f $PIDFILE ]]; then
    pid=$(cat "$PIDFILE")
    kill "$pid" 2>/dev/null || true
    rm -f "$PIDFILE"
  fi
  if [[ -f /tmp/wh-sort-fifo-holder.pid ]]; then
    kill "$(cat /tmp/wh-sort-fifo-holder.pid)" 2>/dev/null || true
    rm -f /tmp/wh-sort-fifo-holder.pid
  fi
  # Legacy sortbloom-era holder pid (pre-rename); cleaned up so reboots
  # from old shells don't leave a zombie writer.
  if [[ -f /tmp/sortbloom-fifo-holder.pid ]]; then
    kill "$(cat /tmp/sortbloom-fifo-holder.pid)" 2>/dev/null || true
    rm -f /tmp/sortbloom-fifo-holder.pid
  fi
  pkill -f "flutter.*--web-port[= ]*$PORT" 2>/dev/null || true
  rm -f "$FIFO"
  echo "Stopped."
}

status() {
  if [[ -f $PIDFILE ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Running (pid $(cat "$PIDFILE")) on http://127.0.0.1:$PORT"
    return 0
  fi
  echo "Not running."
  return 1
}

case "$cmd" in
  start) start ;;
  stop) stop ;;
  restart) restart ;;
  reload) reload ;;
  logs) logs ;;
  status) status ;;
  *) echo "Usage: $0 {start|stop|restart|reload|logs|status}"; exit 1 ;;
esac
