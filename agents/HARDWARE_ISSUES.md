# Hardware Issues Log

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

### Action Items
- [ ] Check chassis airflow — yak needs strong front-to-back ventilation for 2× A40 under load
- [ ] Consider adding case fans or improving rack airflow
- [ ] Monitor GPU temps via Prometheus/Grafana (vLLM exposes `vllm:gpu_temperature_celsius` or use `nvidia_smi_exporter`)
- [ ] Consider lowering `--gpu-memory-utilization` from 0.90 if thermals remain problematic
- [ ] Add thermal alerts to observability stack (alert at 85°C, critical at 90°C)
- [ ] Investigate whether MoE workloads generate more heat than dense models (128-expert routing = higher compute utilization)

### Config at Time of Failure
- Config J: capacity mode
- GPU 0: light-0 — Qwen3-30B-A3B MoE AWQ, 0.90 util, 65K context
- GPU 1: light-1 — Qwen3-30B-A3B MoE AWQ, 0.90 util, 65K context (failed)
- Ambient conditions: unknown, needs baseline measurement
