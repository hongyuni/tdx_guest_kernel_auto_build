#!/bin/bash

rm td_guest_linux_next.log
./tdx.linux_next.sh 2>&1 | tee td_guest_linux_next.log
DAY_INFO=$(date +20%y%m%d)
cp td_guest_linux_next.log /var/www/html/tdx-linux-next/td_guest_linux_next.${DAY_INFO}.log
