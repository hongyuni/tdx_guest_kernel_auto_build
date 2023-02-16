#!/bin/bash

rm td_guest_linux_next.log
./tdx.linux_next.sh 2>&1 | tee td_guest_linux_next.log
DAY_INFO=$(date +%y-%m-%d)
cp td_guest_linux_next.log td_guest_linux_next.${DAY_INFO}.log
