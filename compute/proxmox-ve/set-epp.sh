#!/usr/bin/env bash
# Set every CPU to the "power" epp

for epp_file in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    # Only touch the file if it exists (CPU may be disabled)
    if [[ -w "$epp_file" ]]; then
        # Choose between: performance, balance_performance, balance_power, or power
        echo balance_power > "$epp_file"
    fi
done
