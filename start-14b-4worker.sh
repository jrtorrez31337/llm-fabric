#!/usr/bin/env bash
# Start SSW AI inference + observability stacks.
#
#   Usage:  ./start-14b-4worker.sh [--no-obs]
#
# Both stacks run under project "sswai" and share the sswai_default network
# so Prometheus can reach vLLM workers by service name.

set -euo pipefail
cd "$(dirname "$0")"

OBS=true
for arg in "$@"; do
  [[ "$arg" == "--no-obs" ]] && OBS=false
done

echo "==> Starting vLLM stack  (Qwen3-14B-AWQ × 4 workers, 48K context)..."
docker compose \
  -p sswai \
  -f docker-compose.14b-4worker.yml \
  --env-file .env.14b-4worker \
  up -d

if $OBS; then
  echo "==> Starting observability stack  (Prometheus + Grafana)..."
  docker compose \
    -p sswai \
    -f docker-compose.observability.yml \
    up -d
fi

echo ""
echo "Stack ready:"
echo "  Gateway     http://localhost:8000"
echo "  Prometheus  http://localhost:9090"
if $OBS; then
  echo "  Grafana     http://localhost:3000  (admin / sswai)"
fi
