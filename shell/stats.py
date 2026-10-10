#!/usr/bin/env python3
"""Fast, dependency-free Linux CPU/RAM summary for the Vesly prompt."""
import time

def cpu():
    with open("/proc/stat", encoding="ascii") as handle:
        values = [int(x) for x in handle.readline().split()[1:11]]
    return sum(values), values[3] + values[4]

try:
    before, idle_before = cpu()
    time.sleep(0.07)
    after, idle_after = cpu()
    busy = (after - before) - (idle_after - idle_before)
    percent = 100.0 * busy / (after - before) if after > before else 0.0
    total = available = 0
    with open("/proc/meminfo", encoding="ascii") as handle:
        for line in handle:
            if line.startswith("MemTotal:"):
                total = int(line.split()[1])
            elif line.startswith("MemAvailable:"):
                available = int(line.split()[1])
    if total:
        used_gb = (total - available) / (1024 * 1024)
        total_gb = total / (1024 * 1024)
        print(f"CPU {max(0, min(100, percent)):.0f}% │ RAM {used_gb:.0f}/{total_gb:.0f}G")
    else:
        print(f"CPU {max(0, min(100, percent)):.0f}%")
except (OSError, ValueError, IndexError):
    pass
