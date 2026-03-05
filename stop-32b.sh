#!/usr/bin/env bash
# Stop SSW AI inference + observability stacks.
#
#   Usage:  ./stop-32b.sh

set -euo pipefail
cd "$(dirname "$0")"

echo "==> Stopping all sswai services..."
docker compose \
  -p sswai \
  -f docker-compose.32b-1per-gpu.yml \
  -f docker-compose.observability.yml \
  --env-file .env.32b-1per-gpu \
  down

echo ""
echo "All services stopped."
