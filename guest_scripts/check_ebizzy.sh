#!/usr/bin/bash

/root/ebizzy -M 
ebizzy_malloc=$?
/root/ebizzy -m
ebizzy_mmap=$?

if [[ $ebizzy_malloc -eq 0 && $ebizzy_mmap -eq 0 ]]; then
    echo "ebizzy test SUCCESS"
else
    poweroff
fi