#!/usr/bin/bash

attest_dev=$(ls $1)

if [ -c "${attest_dev}" ]; then
    echo "${attest_dev} exists."
else
    poweroff
fi
