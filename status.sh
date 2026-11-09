
#!/usr/bin/env bash

set -u

# Move into the directory where this script resides
cd "$(dirname "$0")" || exit 1

# Load environment variables
if [[ ! -f .env ]]; then
    echo "ERROR: .env file not found."
    exit 1
fi

set -a
source .env
set +a

# Check a server's process and API health
check_server() {
    local NAME="$1"
    local PORT="$2"
    local PID_FILE="logs/$NAME.pid"

    echo ""
    echo "Checking $NAME server..."

    # Check PID file
    if [[ ! -f "$PID_FILE" ]]; then
        echo "  Process: NOT RUNNING (PID file missing)"
        return
    fi

    local PID
    PID=$(<"$PID_FILE")

    # Validate PID
    if [[ ! "$PID" =~ ^[0-9]+$ ]]; then
        echo "  Process: ERROR (invalid PID file)"
        return
    fi

    # Check process
    if kill -0 "$PID" 2>/dev/null; then
        echo "  Process: RUNNING (PID: $PID)"
    else
        echo "  Process: STOPPED (stale PID file)"
        return
    fi

    # Check API health
    if curl -fsS --max-time 3 \
        "http://127.0.0.1:$PORT/health" >/dev/null; then
        echo "  API: HEALTHY (port $PORT)"
    else
        echo "  API: NOT READY (port $PORT)"
    fi
}

echo "================================"
echo "       LOCAL LLM STATUS"
echo "================================"

check_server chat "${CHAT_PORT:?CHAT_PORT is missing}"
check_server embed "${EMBED_PORT:?EMBED_PORT is missing}"

echo ""
echo "================================"

