#!/usr/bin/env bash
# Stop SSW AI inference + observability stacks.
#
#   Usage:  ./stop-14b-4worker.sh

set -euo pipefail
cd "$(dirname "$0")"

echo "==> Stopping all sswai services..."
docker compose \
  -p sswai \
  -f docker-compose.14b-4worker.yml \
  -f docker-compose.observability.yml \
  --env-file .env.14b-4worker \
  down

echo ""
echo "All services stopped."
