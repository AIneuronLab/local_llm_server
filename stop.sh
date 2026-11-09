#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

if [[ ! -f .env ]]; then
    echo "ERROR: .env file not found!"
    exit 1
fi

set -a
source .env
set +a

stop_server() {
    local NAME="$1"
    local PORT="$2"

    local PIDS
    PIDS=$(lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)

    if [[ -z "$PIDS" ]]; then
        echo "$NAME server is not running."
        return
    fi

    for PID in $PIDS; do
        echo "Stopping $NAME server (PID: $PID)..."
        kill "$PID" 2>/dev/null || true
    done

    # shellcheck disable=SC2034
    for i in {1..10}; do
        if ! lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
            echo "$NAME server stopped."
            rm -f "logs/$NAME.pid"
            return
        fi

        sleep 1
    done

    echo "WARNING: $NAME server did not stop gracefully."

    PIDS=$(lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)

    for PID in $PIDS; do
        echo "Force stopping PID: $PID"
        kill -9 "$PID" 2>/dev/null || true
    done

    rm -f "logs/$NAME.pid"
}

stop_server chat "$CHAT_PORT"
stop_server embed "$EMBED_PORT"