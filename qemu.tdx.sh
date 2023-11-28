#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
echo $SCRIPT_DIR

#TDX guest kernel image passed by argument
KERNEL_IMAGE=$1
#TDVF from edk2 upstream
BIOS_IMAGE=/usr/share/qemu/OVMF.fd
#QEMU from github tdx-qemu dev repo
QEMU_IMAGE=/tdx/home/sdp/tdx/host_qemu_github/qemu-tdx/build/qemu-system-x86_64.tdx-qemu-2023.9.21-v8.1.0-kvm-upstream-2023.9.19-v6.6-rc1-wa
#GUEST_IMAGE qcow2 file
GUEST_IMAGE=/tdx/home/sdp/tdx/hongyu/td-guest-centos-stream-8.common.qcow2
#TDX guest bootup parameters
CPU=$2
SOCKET=$3
MEM=$4
DEBUG=$5

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
	-smp cpus=${CPU},sockets=${SOCKET} \
	-m ${MEM}G \
	-object '{"qom-type":"tdx-guest","id":"tdx","debug":true,"sept-ve-disable":true,"quote-generation-socket":{"type": "vsock", "cid":"2","port":"4050"}}' \
	-object memory-backend-ram,id=ram1,size=${MEM}G,private=on \
	-machine q35,kernel_irqchip=split,confidential-guest-support=tdx,memory-backend=ram1 \
	-bios $BIOS_IMAGE \
	-d guest_errors \
	-nographic \
	-vga none \
	-device virtio-net-pci,netdev=mynet0,mac=00:16:3E:68:08:FF,romfile= \
	-netdev user,id=mynet0,hostfwd=tcp::10099-:22,hostfwd=tcp::12099-:2375 \
	-device vhost-vsock-pci,guest-cid=99 \
	-chardev stdio,id=mux,mux=on,signal=off \
	-device virtio-serial,romfile= \
	-device virtconsole,chardev=mux \
	-serial chardev:mux \
	-monitor chardev:mux \
	-drive file=${GUEST_IMAGE},if=virtio,format=qcow2 \
	-kernel ${KERNEL_IMAGE} \
	-append "root=/dev/vda3 ro console=hvc0 earlyprintk=ttyS0 ignore_loglevel debug earlyprintk l1tf=off initcall_debug log_buf_len=200M swiotlb=force tsc=reliable efi=debug nokaslr" \
	-monitor pty \
	-monitor telnet:127.0.0.1:9099,server,nowait \
	-no-hpet \
	-nodefaults \
