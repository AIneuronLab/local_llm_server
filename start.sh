
#!/usr/bin/env bash

# Shebang: run this script with Bash
set -euo pipefail

# Move into the directory where this script lives
cd "$(dirname "$0")"

echo "Starting LLM servers..."
echo "Executed from: $(pwd)"

# Check that .env exists
if [[ ! -f .env ]]; then
    echo "ERROR: .env file not found!"
    exit 1
fi

# Load environment variables and export them
set -a
source .env
set +a

# Required environment variables
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

# Validate required variables
for VAR in "${REQUIRED[@]}"; do
    if [[ -z "${!VAR}" ]]; then
        echo "ERROR: $VAR is empty or missing."
        exit 1
    fi
done

echo "All environment variables loaded successfully!"

# Create logs directory
mkdir -p logs

# Start CHAT SERVER
echo "Starting CHAT SERVER..."

LLM_API_KEY="$LLM_API_KEY" nohup llama-server \
    --model "$CHAT_MODEL" --alias local-llm \
    --host 127.0.0.1 --port "$CHAT_PORT" \
    --n-gpu-layers 99 \
    --parallel "$CHAT_PARALLEL" --ctx-size "$CHAT_CTX" \
    --flash-attn on --cache-type-k q8_0 --cache-type-v q8_0 \
    --n-predict "$CHAT_MAX_TOKENS" \
    --reasoning-budget 0 \
    --jinja \
    --metrics \
    > logs/chat.log 2>&1 &

echo $! > logs/chat.pid
echo "CHAT SERVER STARTED (PID: $(cat logs/chat.pid))"

# Start EMBEDDING SERVER
echo "Starting EMBEDDING SERVER..."

LLM_API_KEY="$LLM_API_KEY" nohup llama-server \
    --model "$EMBED_MODEL" --alias local-embed \
    --host 127.0.0.1 --port "$EMBED_PORT" \
    --n-gpu-layers 99 \
    --embedding --pooling last \
    --ctx-size "$EMBED_CTX" \
    --batch-size "$EMBED_CTX" \
    --ubatch-size "$EMBED_CTX" \
    > logs/embed.log 2>&1 &

echo $! > logs/embed.pid
echo "EMBEDDING SERVER STARTED (PID: $(cat logs/embed.pid))"

echo "Both server startup commands have been launched."
