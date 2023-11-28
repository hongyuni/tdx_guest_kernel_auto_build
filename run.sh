#!/bin/bash

rm -rf test_tdx.log
rm -rf vm_*.log
./tdx.intel_next.sh 2>&1 | tee test_tdx.log
DAY_INFO=$(date +20%y%m%d)
sleep 10
cd /www/html/tdx-intel-next
mkdir -p ${DAY_INFO}
cd -
cp test_tdx.log /www/html/tdx-intel-next/${DAY_INFO}/
cp vm_*.log /www/html/tdx-intel-next/${DAY_INFO}/
