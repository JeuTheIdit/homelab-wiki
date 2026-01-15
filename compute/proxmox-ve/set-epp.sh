#!/usr/bin/env bash
# set every CPUs epp

for epp_file in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    # only touch the file if it exists (CPU may be disabled)
    if [[ -w "$epp_file" ]]; then
        # choose between: performance, balance_performance, balance_power, or power
        echo balance_power > "$epp_file"
    fi
done
