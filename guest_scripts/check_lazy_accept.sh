#!/usr/bin/bash

bootup_vmstat=$(grep "nr_unaccepted" /proc/vmstat | cut -d' ' -f2)
echo "nr_unaccepted: ${bootup_vmstat}"
nohup stress --vm-bytes $(awk '/MemAvailable/{printf "%d\n", $2;}' </proc/meminfo)k --vm-keep -m 1 &
# sleep 3s to wait for the vmstat indicator refreshed
sleep 5
stress_vmstat=$(grep "nr_unaccepted" /proc/vmstat | cut -d' ' -f2)
echo "after stress, nr_unaccepted: ${stress_vmstat}"

if [ $bootup_vmstat -gt $stress_vmstat ]; then
    echo "TDX guest lazy_accept vmstat test PASS"
    kill $(pidof stress)
else
    poweroff 
fi
