#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
echo $SCRIPT_DIR

#TDX guest kernel image passed by argument
KERNEL_IMAGE=$1
#TDVF from edk2 upstream
BIOS_IMAGE=/tdx/home/sdp/tdx/hongyu/OVMF.edk2-stable202211.fd
#QEMU from github tdx-qemu dev repo
QEMU_IMAGE=/tdx/home/sdp/tdx/host_qemu_github/qemu-tdx/build/qemu-system-x86_64.tdx-qemu-2023-3-13-v7.2-kvm-upstream-2023.03.10-v6.2-wa
#GUEST_IMAGE qcow2 file
GUEST_IMAGE=/tdx/home/sdp/tdx/hongyu/td-guest-centos-stream-8.common.qcow2

$QEMU_IMAGE \
	-accel kvm \
	-no-reboot \
	-name process=legacy_vm,debug-threads=on \
	-cpu host,host-phys-bits,pmu=off \
	-smp cpus=4,sockets=1 \
	-m 4G \
	-machine q35,kernel_irqchip=split \
	-bios $BIOS_IMAGE \
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
