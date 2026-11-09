#!/usr/bin/env bash

set -e

cd "$(dirname "$0")" || exit 1

echo "Restarting LLM servers..."

./stop.sh
sleep 2
./start.sh

echo "Restart completed!"
