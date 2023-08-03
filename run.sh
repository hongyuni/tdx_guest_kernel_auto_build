#!/bin/bash

rm -rf test_tdx.log
rm -rf vm_*.log
./tdx.linux_next.sh 2>&1 | tee test_tdx.log
DAY_INFO=$(date +20%y%m%d)
sleep 10
cd /tdx/www/html/tdx-linux-next
mkdir -p ${DAY_INFO}
cd -
cp test_tdx.log /tdx/www/html/tdx-linux-next/${DAY_INFO}/
cp vm_*.log /tdx/www/html/tdx-linux-next/${DAY_INFO}/
