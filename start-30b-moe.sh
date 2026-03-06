#!/usr/bin/env bash
# Start SSW AI inference (Qwen3-30B-A3B MoE AWQ, 1 per GPU) + observability.
#
#   Usage:  ./start-30b-moe.sh [--no-obs]

set -euo pipefail
cd "$(dirname "$0")"

OBS=true
for arg in "$@"; do
  [[ "$arg" == "--no-obs" ]] && OBS=false
done

# Select Prometheus config for 2-worker scrape targets
cp prometheus/prometheus.30b-moe.yml prometheus/prometheus.yml

echo "==> Starting vLLM stack  (Qwen3-30B-A3B MoE AWQ × 2 workers, 48K context)..."
docker compose \
  -p sswai \
  -f docker-compose.30b-moe.yml \
  --env-file .env.30b-moe \
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
echo "  Gateway     http://localhost:8000  (2 MoE workers, 1/GPU)"
if $OBS; then
  echo "  Prometheus  http://localhost:9090"
  echo "  Grafana     http://localhost:3000  (admin / sswai)"
fi
