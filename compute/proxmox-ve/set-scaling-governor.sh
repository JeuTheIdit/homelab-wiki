#!/usr/bin/env bash
# set every CPU scaling governor

for governor_file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    # only touch the file if it exists (CPU may be disabled)
    if [[ -w "$governor_file" ]]; then
        # choose between perfromance or powersave
        echo powersave > "$governor_file"
    fi
done
