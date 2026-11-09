#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

echo "Starting LLM servers..."
echo "Executed from: $(pwd)"

if [[ ! -f .env ]]; then
    echo "ERROR: .env file not found!"
    exit 1
fi

set -a
source .env
set +a

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


check_running() {
    local NAME="$1"
    local PID_FILE="logs/$NAME.pid"

    if [[ ! -f "$PID_FILE" ]]; then
        return 1
    fi

    local PID
    PID=$(<"$PID_FILE")

    if [[ "$PID" =~ ^[0-9]+$ ]] && kill -0 "$PID" 2>/dev/null; then
        return 0
    fi

    rm -f "$PID_FILE"
    return 1
}


if check_running chat; then
    echo "CHAT server is already running. Restarting..."
    ./stop.sh
    sleep 2
else
    echo "CHAT server is not running. Starting it..."
fi


if check_running embed; then
    echo "EMBED server is already running. Restarting..."
    ./stop.sh
    sleep 2
else
    echo "EMBED server is not running. Starting it..."
fi


echo "Starting CHAT SERVER..."

LLM_API_KEY="$LLM_API_KEY" nohup llama-server \
    --model "$CHAT_MODEL" \
    --alias local-llm \
    --host 127.0.0.1 \
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

echo $! > logs/chat.pid

echo "CHAT SERVER STARTED (PID: $(<logs/chat.pid))"


echo "Starting EMBEDDING SERVER..."

LLM_API_KEY="$LLM_API_KEY" nohup llama-server \
    --model "$EMBED_MODEL" \
    --alias local-embed \
    --host 127.0.0.1 \
    --port "$EMBED_PORT" \
    --n-gpu-layers 99 \
    --embedding \
    --pooling last \
    --ctx-size "$EMBED_CTX" \
    --batch-size "$EMBED_CTX" \
    --ubatch-size "$EMBED_CTX" \
    > logs/embed.log 2>&1 &

echo $! > logs/embed.pid

echo "EMBEDDING SERVER STARTED (PID: $(<logs/embed.pid))"

echo ""
echo "Both LLM servers are running."