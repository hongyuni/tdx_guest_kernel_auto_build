#!/usr/bin/bash

cpu_param=$1
cpu_actual=$(lscpu | grep "CPU(s)" | head -1 | awk {'print $2'})
tdx_flags=$(lscpu | grep "Flags" | grep "tdx_guest")

if [ $cpu_param -ne $cpu_actual ] || [ -z "${tdx_flags}" ]; then
    poweroff
else
    echo "CPU number is correct and TDX is enabled in guest."
fi
