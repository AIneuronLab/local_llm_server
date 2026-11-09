#!/usr/bin/env bash

cd "$(dirname "$0")" || exit 1

for s in chat embed; do
    PID_FILE="logs/$s.pid"

    if [[ -f "$PID_FILE" ]]; then
        PID=$(<"$PID_FILE")

        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            echo "Stopped $s Server (PID: $PID)."
        else
            echo "$s Server is already stopped (stale PID: $PID)."
        fi

        rm -f "$PID_FILE"
    else
        echo "$s Server has no PID file."
    fi
done