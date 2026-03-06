#!/usr/bin/env bash
# Stop SSW AI inference (30B MoE) + observability stacks.
#
#   Usage:  ./stop-30b-moe.sh

set -euo pipefail
cd "$(dirname "$0")"

echo "==> Stopping all sswai services..."
docker compose \
  -p sswai \
  -f docker-compose.30b-moe.yml \
  -f docker-compose.observability.yml \
  --env-file .env.30b-moe \
  down

echo ""
echo "All services stopped."
