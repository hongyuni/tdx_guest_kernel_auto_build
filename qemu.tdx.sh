#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
echo $SCRIPT_DIR

#TDX guest kernel image passed by argument
KERNEL_IMAGE=$1
#TDVF from edk2 upstream
BIOS_IMAGE=/home/sdp/tdx/hongyu/OVMF.edk2-stable202211.fd
#QEMU from github tdx-qemu dev repo
QEMU_IMAGE=/home/sdp/tdx/hongyu/git_qemu_tdx/qemu-tdx/build/qemu-system-x86_64.tdx-upstream-wip-2022-11-16-v7.1
#GUEST_IMAGE qcow2 file
GUEST_IMAGE=/home/sdp/tdx/hongyu/td-guest-centos-stream-8.linux_next.qcow2
MEM=1G

if [[ ! -f $QEMU_IMAGE ]]; then
	echo "Qemu image $QEMU_IMAGE does not exist"
	exit 1
else
	echo "Using Qemu binary $QEMU_IMAGE"
fi


if [[ ! -f $KERNEL_IMAGE ]]; then
	echo "Guest kernel $KERNEL_IMAGE does not exist"
	exit 1
else
	echo "Guest kernel is $KERNEL_IMAGE"
fi

TDX_SYSFS_FILE="/sys/module/kvm_intel/parameters/tdx"
if [[ -f $TDX_SYSFS_FILE ]]; then
	if [ "Y" != "$(cat $TDX_SYSFS_FILE)" ] ;then
    		echo "Please set tdx kvm_intel params to Y"
		exit 1
	fi
else
	echo "tdx modules params does not exist, reload correct kvm"
	exit 1
fi



$QEMU_IMAGE \
	-accel kvm \
	-no-reboot \
	-name process=tdxvm_hy,debug-threads=on \
	-cpu host,host-phys-bits,pmu=off \
	-smp cpus=4,cores=4,threads=1,sockets=1 \
	-m ${MEM} \
	-object tdx-guest,id=tdx,debug=on,sept-ve-disable=on,quote-generation-service=vsock:2:4050 \
    -object memory-backend-memfd-private,id=ram1,size=${MEM} \
	-machine q35,kernel_irqchip=split,confidential-guest-support=tdx,memory-backend=ram1 \
	-bios $BIOS_IMAGE \
    -d guest_errors \
	-nographic \
	-vga none \
	-device virtio-net-pci,netdev=mynet0,mac=00:16:3E:68:08:FF,romfile= \
    -netdev user,id=mynet0,hostfwd=tcp::10007-:22,hostfwd=tcp::12007-:2375 \
    -device vhost-vsock-pci,guest-cid=7 \
	-chardev stdio,id=mux,mux=on,signal=off \
    -device virtio-serial,romfile= \
	-device virtconsole,chardev=mux \
    -serial chardev:mux \
	-monitor chardev:mux \
	-drive file=${GUEST_IMAGE},if=virtio,format=qcow2 \
	-kernel ${KERNEL_IMAGE} \
	-append "root=/dev/vda3 ro console=hvc0 earlyprintk=ttyS0 ignore_loglevel debug earlyprintk l1tf=off initcall_debug log_buf_len=200M swiotlb=force tsc=reliable efi=debug noapic nokaslr" \
	-monitor pty \
    -monitor telnet:127.0.0.1:9007,server,nowait \
    -no-hpet \
    -nodefaults \
