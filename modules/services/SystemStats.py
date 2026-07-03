#!/usr/bin/env python3
"""One-shot system-stat reader for the Quickshell bar.

Called every ~2 s by the QML Timer. Reads CPU / RAM / GPU from cheap sources
and prints one JSON line. Designed to be very light: only a few file reads and
(optionally) one nvidia-smi / sysfs read per invocation.
"""

import json
import os
import subprocess
import sys
import time


def read_cpu_times():
    with open("/proc/stat", "rb") as f:
        line = f.readline()
    parts = line.split()
    if len(parts) < 5 or parts[0] != b"cpu":
        return 0, 0
    values = [int(x) for x in parts[1:]]
    idle = values[3]
    total = sum(values)
    return total, idle


def read_ram_percent():
    total = available = None
    with open("/proc/meminfo", "rb") as f:
        for line in f:
            if line.startswith(b"MemTotal:"):
                total = int(line.split()[1])
            elif line.startswith(b"MemAvailable:"):
                available = int(line.split()[1])
            if total is not None and available is not None:
                break
    if not total:
        return 0.0
    return 100.0 * (total - available) / total


def read_nvidia():
    try:
        out = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=utilization.gpu,name", "--format=csv,noheader,nounits"],
            text=True,
            timeout=1.0,
        )
        parts = out.strip().split(",", 1)
        util = float(parts[0].strip())
        name = parts[1].strip() if len(parts) > 1 else "NVIDIA"
        return util, name
    except Exception:
        return None, None


def read_amd():
    for card in ("card0", "card1", "card2"):
        path = f"/sys/class/drm/{card}/device/gpu_busy_percent"
        name_path = f"/sys/class/drm/{card}/device/product_name"
        if os.path.exists(path):
            try:
                with open(path, "r") as f:
                    util = float(f.read().strip())
            except Exception:
                util = 0.0
            name = "AMD"
            if os.path.exists(name_path):
                try:
                    with open(name_path, "r") as f:
                        name = f.read().strip()
                except Exception:
                    pass
            return util, name
    return None, None


def read_gpu():
    util, name = read_nvidia()
    if util is not None:
        return util, name
    util, name = read_amd()
    if util is not None:
        return util, name
    return 0.0, "GPU"


def main():
    prev_total, prev_idle = read_cpu_times()
    time.sleep(0.5)
    total, idle = read_cpu_times()
    delta_total = total - prev_total
    delta_idle = idle - prev_idle
    cpu = 100.0 * (1.0 - delta_idle / delta_total) if delta_total > 0 else 0.0
    ram = read_ram_percent()
    gpu, gpu_name = read_gpu()
    print(
        json.dumps(
            {
                "cpu": round(max(0.0, min(100.0, cpu)), 1),
                "ram": round(max(0.0, min(100.0, ram)), 1),
                "gpu": round(max(0.0, min(100.0, gpu)), 1),
                "gpuName": gpu_name,
            }
        ),
        flush=True,
    )


if __name__ == "__main__":
    main()
