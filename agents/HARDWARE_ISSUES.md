# Hardware Issues Log

## 2026-03-25: Unclean Power Loss (Plug Pulled)

### Symptoms
- Yak lost power abruptly (physical plug pulled due to fan noise complaint)
- System rebooted automatically ~4h before discovery
- Gateway was down — game VM traffic getting no responses

### What Survived (Docker restart:unless-stopped)
- Both A40 GPUs — alive, 48°C / 43°C at idle
- light-0 + light-1 (vLLM workers) — healthy, serving requests
- Redis — healthy
- Prometheus + Grafana — running

### What Was Down
- **Gateway**: systemd ran Config H compose (wrong file — sswai.service not yet updated), created dead `sswai-gateway-1`. Config J gateway (`sswai-gateway`) never started.
- **Masheen fast tier**: WireGuard reachable but vLLM on port 8001 not responding. Required restart on masheen box.
- **Stale containers**: 4 Config H containers in "Created" state (sswai-gateway-1, sswai-model-0-1, sswai-model-1-1, sswai-loader-1)

### Root Cause
Physical power interruption. systemd auto-start used wrong compose file (Config H instead of Config J). Workers survived on Docker restart policy. Gateway did not because Config J gateway was never registered with the old systemd unit.

### Resolution
1. Removed 4 stale Config H containers
2. Started Config J gateway via `docker compose -p sswai -f docker-compose.capacity.yml --env-file .env.capacity up -d gateway`
3. Updated systemd unit to Config J: description, compose file, env file
4. `systemctl daemon-reload` applied
5. Masheen vLLM restarted separately
6. Full fleet verified healthy: all 3 Prometheus targets up, all gateway aliases serving

### Action Items
- [x] Start Config J gateway — done
- [x] Clean up stale Config H containers — done
- [x] Update systemd sswai.service → Config J — done
- [x] Restart masheen vLLM — done
- [x] Verify full fleet operational — done
- [ ] Consider UPS for yak to prevent future unclean shutdowns

---

## 2026-03-10: GPU 1 Thermal Shutdown + Driver Failure

### Symptoms
- GPU 1 (NVIDIA A40, PCI 0000:82:00.0) became unreachable during Config J deployment
- `nvidia-smi` reported: `Unable to determine the device handle for GPU1: 0000:82:00.0: Unknown Error`
- GPU 0 simultaneously at 99-101°C (thermal throttle territory for A40, max rated 92°C)
- GPU 0 fans reported at 0% — A40 is passively cooled (no onboard fans), relies on chassis airflow
- light-1 container entered crash loop: `NVMLError_Unknown` on `nvmlDeviceGetHandleByIndex`

### Timeline
1. model-heavy (27B dense) stopped on GPU 1 — normal shutdown
2. light-1 (30B MoE) launched on GPU 1 — loaded weights, compiled graphs, served requests
3. ~20 minutes later: light-1 entered restart loop
4. GPU 1 completely unresponsive to driver — thermal protection likely triggered

### Recovery Attempts (all failed, reboot required)
1. `nvidia-smi -i 1 --gpu-reset` — failed, device handle not found
2. PCI reset: `echo 1 > /sys/bus/pci/devices/0000:82:00.0/reset` — no effect
3. PCI remove + rescan: `echo 1 > .../remove` then `echo 1 > /sys/bus/pci/rescan` — GPU 1 did not reappear
4. **Reboot required** to restore GPU 1

### Root Cause Analysis
- **Thermal**: Both GPUs running at 0.90 memory utilization with MoE models (100% GPU-Util on GPU 0)
- A40 is a passively cooled datacenter card — requires sustained front-to-back chassis airflow
- GPU 0 at 99-101°C suggests inadequate cooling for dual-GPU sustained load
- GPU 1 likely hit thermal protection threshold and shut down at hardware level
- A40 thermal throttle starts at 83°C, max operating temp is 92°C — we were 10-20°C over

### Resolution
- **Reboot** restored GPU 1 fully (all recovery attempts without reboot failed)
- Sysadmin agent deployed thermal management tooling
- Post-reboot temps: GPU 0 = 58°C, GPU 1 = 55°C at idle; 59°C / 63°C under load
- Config J redeployed successfully via compose with asymmetric context (GPU 0: 65K, GPU 1: 262K)

### Action Items
- [x] Reboot to recover GPU 1 — successful
- [x] Thermal management — sysadmin agent deployed tooling, temps now stable 58-63°C
- [ ] Monitor GPU temps via Prometheus/Grafana (vLLM exposes `vllm:gpu_temperature_celsius` or use `nvidia_smi_exporter`)
- [ ] Add thermal alerts to observability stack (alert at 85°C, critical at 90°C)
- [ ] Investigate whether MoE workloads generate more heat than dense models (128-expert routing = higher compute utilization)

### Config at Time of Failure
- Config J: capacity mode (standalone containers, before compose migration)
- GPU 0: light-0 — Qwen3-30B-A3B MoE AWQ, 0.90 util, 65K context
- GPU 1: light-1 — Qwen3-30B-A3B MoE AWQ, 0.90 util, 65K context (failed)
- Ambient conditions: inadequate chassis airflow for dual-GPU sustained load
