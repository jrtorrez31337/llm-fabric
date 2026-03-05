#!/usr/bin/env bash
# Start SSW AI inference (Qwen3-32B-AWQ, 1 per GPU) + observability.
#
#   Usage:  ./start-32b.sh [--no-obs]

set -euo pipefail
cd "$(dirname "$0")"

OBS=true
for arg in "$@"; do
  [[ "$arg" == "--no-obs" ]] && OBS=false
done

echo "==> Starting vLLM stack  (Qwen3-32B-AWQ × 2 workers, 48K context)..."
docker compose \
  -p sswai \
  -f docker-compose.32b-1per-gpu.yml \
  --env-file .env.32b-1per-gpu \
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
