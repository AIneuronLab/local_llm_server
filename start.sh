#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

echo "Starting LLM servers..."
echo "Executed from: $(pwd)"

# --------------------------------------------------
# Load environment
# --------------------------------------------------

if [[ ! -f .env ]]; then
    echo "ERROR: .env file not found!"
    exit 1
fi

set -a
source .env
set +a

# --------------------------------------------------
# Validate required variables
# --------------------------------------------------

REQUIRED=(
    "LLM_API_KEY"
    "CHAT_MODEL"
    "EMBED_MODEL"
    "CHAT_PORT"
    "EMBED_PORT"
    "CHAT_PARALLEL"
    "CHAT_CTX"
    "CHAT_MAX_TOKENS"
    "EMBED_CTX"
)

for VAR in "${REQUIRED[@]}"; do
    if [[ -z "${!VAR:-}" ]]; then
        echo "ERROR: $VAR is empty or missing."
        exit 1
    fi
done

mkdir -p logs

# --------------------------------------------------
# Check if something is listening on a port
# --------------------------------------------------

is_running() {
    local PORT="$1"

    lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1
}

# --------------------------------------------------
# Get PID listening on a port
# --------------------------------------------------

get_pid() {
    local PORT="$1"

    lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | head -n 1
}

# --------------------------------------------------
# Check API health
# --------------------------------------------------

is_healthy() {
    local PORT="$1"

    curl -fsS --max-time 3 \
        "http://127.0.0.1:$PORT/health" \
        >/dev/null 2>&1
}

# --------------------------------------------------
# Stop server using its PORT
# --------------------------------------------------

stop_server() {
    local NAME="$1"
    local PORT="$2"

    if is_running "$PORT"; then

        local PID
        PID=$(get_pid "$PORT")

        echo "$NAME server is running (PID: $PID). Stopping it..."

        kill "$PID"

        # Wait for process to disappear
        for i in {1..10}; do

            if ! is_running "$PORT"; then
                echo "$NAME server stopped."
                break
            fi

            sleep 1
        done

        # Still running?
        if is_running "$PORT"; then
            echo "WARNING: $NAME server did not stop gracefully."
            echo "Force stopping PID: $PID"

            kill -9 "$PID" 2>/dev/null || true

            sleep 1
        fi

    else
        echo "$NAME server is not running."
    fi
}

# --------------------------------------------------
# Restart existing servers
# --------------------------------------------------

if is_running "$CHAT_PORT" || is_running "$EMBED_PORT"; then

    echo ""
    echo "LLM server already running."
    echo "Restarting existing servers..."

    stop_server "CHAT" "$CHAT_PORT"
    stop_server "EMBED" "$EMBED_PORT"

else

    echo ""
    echo "No LLM servers are currently running."
    echo "Starting them..."

fi

# Remove old PID files
rm -f logs/chat.pid logs/embed.pid

# --------------------------------------------------
# Start CHAT server
# --------------------------------------------------

echo ""
echo "Starting CHAT SERVER..."

LLM_API_KEY="$LLM_API_KEY" nohup llama-server \
    --model "$CHAT_MODEL" \
    --alias local-llm \
    --host 0.0.0.0 \
    --port "$CHAT_PORT" \
    --n-gpu-layers 99 \
    --parallel "$CHAT_PARALLEL" \
    --ctx-size "$CHAT_CTX" \
    --flash-attn on \
    --cache-type-k q8_0 \
    --cache-type-v q8_0 \
    --n-predict "$CHAT_MAX_TOKENS" \
    --reasoning-budget 0 \
    --jinja \
    --metrics \
    > logs/chat.log 2>&1 &

CHAT_PID=$!

echo "$CHAT_PID" > logs/chat.pid

echo "CHAT SERVER STARTED (PID: $CHAT_PID)"

# --------------------------------------------------
# Wait for CHAT API
# --------------------------------------------------

echo "Waiting for CHAT API..."

CHAT_READY=false

for i in {1..30}; do

    if is_healthy "$CHAT_PORT"; then
        CHAT_READY=true
        break
    fi

    sleep 1

done

if [[ "$CHAT_READY" == true ]]; then

    echo "CHAT API is healthy on port $CHAT_PORT"

else

    echo "ERROR: CHAT API did not become healthy."
    echo "Check logs/chat.log"
    exit 1

fi

# --------------------------------------------------
# Start EMBEDDING server
# --------------------------------------------------

echo ""
echo "Starting EMBEDDING SERVER..."

LLM_API_KEY="$LLM_API_KEY" nohup llama-server \
    --model "$EMBED_MODEL" \
    --alias local-embed \
    --host 0.0.0.0 \
    --port "$EMBED_PORT" \
    --n-gpu-layers 99 \
    --embedding \
    --pooling last \
    --ctx-size "$EMBED_CTX" \
    --batch-size "$EMBED_CTX" \
    --ubatch-size "$EMBED_CTX" \
    > logs/embed.log 2>&1 &

EMBED_PID=$!

echo "$EMBED_PID" > logs/embed.pid

echo "EMBEDDING SERVER STARTED (PID: $EMBED_PID)"

# --------------------------------------------------
# Wait for EMBEDDING API
# --------------------------------------------------

echo "Waiting for EMBEDDING API..."

EMBED_READY=false

for i in {1..30}; do

    if is_healthy "$EMBED_PORT"; then
        EMBED_READY=true
        break
    fi

    sleep 1

done

if [[ "$EMBED_READY" == true ]]; then

    echo "EMBEDDING API is healthy on port $EMBED_PORT"

else

    echo "ERROR: EMBEDDING API did not become healthy."
    echo "Check logs/embed.log"
    exit 1

fi

# --------------------------------------------------
# Done
# --------------------------------------------------

echo ""
echo "========================================"
echo "      LLM SERVERS ARE READY"
echo "========================================"
echo "CHAT      : http://127.0.0.1:$CHAT_PORT"
echo "EMBEDDING : http://127.0.0.1:$EMBED_PORT"
echo "========================================"