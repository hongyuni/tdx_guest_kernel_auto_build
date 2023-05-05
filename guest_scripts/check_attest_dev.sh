#!/usr/bin/bash

attest_dev=$(ls $1)

if [ -z "${attest_dev}" ]; then
    poweroff
else
    echo "${attest_dev} exists."
fi
