#!/usr/bin/env bash
set -euo pipefail

# Measure aggregate completed-request QPS from vLLM worker metrics.
#
# Usage:
#   ./scripts/qps.sh
#   ./scripts/qps.sh 15
#   ./scripts/qps.sh 10 127.0.0.1 8001 8002
#
# Args:
#   $1 = sample window in seconds (default: 10)
#   $2 = host (default: 127.0.0.1)
#   $3.. = worker ports (default: 8001 8002)

WINDOW_SECONDS="${1:-10}"
HOST="${2:-127.0.0.1}"

if ! [[ "$WINDOW_SECONDS" =~ ^[0-9]+$ ]] || [[ "$WINDOW_SECONDS" -le 0 ]]; then
  echo "ERROR: window must be a positive integer (seconds), got: $WINDOW_SECONDS" >&2
  exit 1
fi

if [[ "$#" -ge 3 ]]; then
  shift 2
  PORTS=("$@")
else
  PORTS=(8001 8002)
fi

read_counter() {
  local total=0
  local port
  local value
  local metrics

  for port in "${PORTS[@]}"; do
    metrics="$(curl -fsS "http://${HOST}:${port}/metrics" 2>/dev/null || true)"
    if [[ -z "$metrics" ]]; then
      echo "WARN: could not read metrics from ${HOST}:${port}" >&2
      continue
    fi

    value="$(
      awk '/^vllm:request_success_total\{/ {sum += $2} END {printf "%.0f", sum+0}' <<<"$metrics"
    )"
    total=$((total + value))
  done

  echo "$total"
}

start_count="$(read_counter)"
start_ts="$(date +%s)"
sleep "$WINDOW_SECONDS"
end_count="$(read_counter)"
end_ts="$(date +%s)"

completed="$((end_count - start_count))"
elapsed="$((end_ts - start_ts))"

awk \
  -v host="$HOST" \
  -v ports="$(IFS=,; echo "${PORTS[*]}")" \
  -v completed="$completed" \
  -v elapsed="$elapsed" \
  'BEGIN {
    qps = (elapsed > 0) ? (completed / elapsed) : 0
    printf("host=%s ports=%s window=%ss completed=%d qps=%.2f\n", host, ports, elapsed, completed, qps)
  }'
