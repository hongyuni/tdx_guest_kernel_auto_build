#!/usr/bin/bash

# DESCRIPTION #
# a template to test mainline linux_next kernel as TD guest image
##  step 0: create $KERNEL_PATH if not exists and git clone from linux-next repo
##  step 1: git checkout to latest release tag $TAG from above branch
##  step 2: ./scripts/config revise CONFIG_INTEL_TDX_GUEST=y and append tag info $TAG to CONFIG_LOCALVERSION
##  step 3: compile kernel and cp it as bzImage.$TAG
##  step 4: pass above kernel bzImage to td_guest_boot.sh for TD guest booting test
# DESCRIPTION END #

# variables
KERNEL_PATH=/tdx/root/linux_next_mainline

# common functions
script_path() {
  SCRIPT_PATH="$( cd "$( dirname "$0" )" && pwd )"
  [ -z "$SCRIPT_PATH" ] && exit 1
  echo "$SCRIPT_PATH"
}

clone() {
  [ ! -d "${KERNEL_PATH}" ] && mkdir "${KERNEL_PATH}"
  cd "${KERNEL_PATH}" || exit 1
  echo "switched to ${KERNEL_PATH}"
  #git clone https://github.com/torvalds/linux.git
  git clone https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
  cd -- || exit 1
}

checkout() {
  cd "${KERNEL_PATH}"/linux-next || exit 1
  git checkout master
  git reset --hard origin/master
  echo "start to checkout to latest tag..."
  git fetch --all
  TAG=$(git tag --list --sort=-creatordate | head -1)
  #TAG="next-20230530"
  git checkout "${TAG}"
  TAG_VERIFY=$(git describe --tags --exact-match)
  [ "${TAG}" = "${TAG_VERIFY}" ] || exit 1
  echo "checkout to tag:'${TAG}' done..."
  cd -- || exit 1
}

kconfig() {
  cd "${KERNEL_PATH}"/linux-next || exit 1
  cp "$SOURCE_PATH"/tdx.gold.config .config
  make olddefconfig
  ./scripts/config --enable CONFIG_INTEL_TDX_GUEST --enable CONFIG_VIRT_DRIVERS --enable CONFIG_TDX_GUEST_DRIVER --enable CONFIG_KVM_GUEST
  ./scripts/config --enable CONFIG_FUSE_FS --enable CONFIG_VIRTIO_FS --enable CONFIG_VIRTIO_BALLOON --enable CONFIG_VIRTIO_PMEM
  ./scripts/config --enable CONFIG_XFS_SUPPORT_V4 --enable CONFIG_XFS_ONLINE_SCRUB --enable CONFIG_XFS_ONLINE_REPAIR --enable CONFIG_XFS_WARN --enable CONFIG_XFS_DEBUG
  ./scripts/config --set-str CONFIG_LOCALVERSION -"$TAG"
  yes "" | make config
  grep -r "CONFIG_INTEL_TDX_GUEST=y" .config || exit 1
  grep -r "CONFIG_KVM_GUEST=y" .config || exit 1
  grep -r "CONFIG_TDX_GUEST_DRIVER=y" .config || exit 1
  #./scripts/config --set-str CONFIG_LOCALVERSION -"$TAG"
}

compile() {
  cd "${KERNEL_PATH}"/linux-next || exit 1
  rm -rf arch/x86/boot/bzImage
  grep -r "CONFIG_INTEL_TDX_GUEST=y" .config || exit 1
  grep -r "CONFIG_KVM_GUEST=y" .config || exit 1
  grep -r "CONFIG_TDX_GUEST_DRIVER=y" .config || exit 1
  make ARCH=x86_64 CC="ccache gcc" -j"$(nproc)" -C ./
  cp arch/x86/boot/bzImage arch/x86/boot/bzImage."$TAG"
}

#set -x

echo "####################################################################"
echo "step 0:"
echo "create $KERNEL_PATH if not exists and git clone from linux-next repo"
echo "####################################################################"
SOURCE_PATH=$(script_path)

# Do the work
# step 0
[ ! -d "$KERNEL_PATH"/linux-next ] && clone

echo "####################################################################"
echo "step 1:"
echo "git checkout to latest release tag $TAG from above branch"
echo "####################################################################"

# step 1
checkout

echo "####################################################################"
echo "step 2:"
echo "revise CONFIG_INTEL_TDX_GUEST=y/CONFIG_TDX_GUEST_DRIVER=y/CONFIG_KVM_GUEST=y and append tag info $TAG to CONFIG_LOCALVERSION"
echo "####################################################################"

# step 2
kconfig

echo "####################################################################"
echo "step 3:"
echo "compile kernel and cp it as bzImage.$TAG"
echo "####################################################################"

# step 3
compile

echo "####################################################################"
echo "step 4:"
echo "pass bzImage.$TAG to qemu.tdx.sh for TD guest booting test"
echo "####################################################################"
grep -r "CONFIG_INTEL_TDX_GUEST=y" .config || exit 1
grep -r "CONFIG_KVM_GUEST=y" .config || exit 1
grep -r "CONFIG_TDX_GUEST_DRIVER=y" .config || exit 1
KERNEL_IMAGE="$KERNEL_PATH"/linux-next/arch/x86/boot/bzImage."${TAG}"

# Please pre-set the guest image passwd to 123456
export SSHPASS='123456'
PORT=10099
ATTEST_DEV=/dev/tdx_guest
SLEEP=30

prepare_guest_image()
{
  sleep $SLEEP
  sshpass -e scp -P $PORT ${SOURCE_PATH}/guest_scripts/* root@localhost:/root/
  sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "chmod +x /root/*.sh"
  sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "yum install stress -y"

  sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "[[ -e /root/2023WW23.tar.gz ]] || wget http://hongyu-dev.sh.intel.com/2023WW23.tar.gz -P /root/"
  sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "cd /root && [[ -e 2023WW23 ]] || tar -zxvf 2023WW23.tar.gz"

  sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "poweroff"
}

check_lscpu()
{
  sleep $SLEEP
  sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "sh /root/check_lscpu.sh ${1}"
  if [ $? -ne 0 ]; then
    echo "TDX is not enabled in guest or CPU number is not correct"
    exit 1
  fi
}

check_mem()
{
	sleep $SLEEP
	sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "cat /proc/meminfo"
	if [ $? -ne 0 ]; then
		echo "Failed to check /proc/meminfo"
		exit 1
	fi
}

check_attest_dev()
{
  sleep $SLEEP
  sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "sh /root/check_attest_dev.sh ${ATTEST_DEV}"
  if [ $? -ne 0 ]; then
    echo "TDX attest device doesn't exist."
    exit 1
  fi
  sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "systemctl reboot now"
}

check_lazy_accept()
{
  sleep $SLEEP
  sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "sh /root/check_lazy_accept.sh"
  if [ $? -ne 0 ]; then
    echo "TDX attest device doesn't exist."
    exit 1
  fi
  sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "systemctl reboot now"
}

check_ebizzy()
{
  sleep $SLEEP
  sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "sh /root/check_ebizzy.sh"
  if [ $? -ne 0 ]; then
    echo "TDX attest device doesn't exist."
    exit 1
  fi
  sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "systemctl reboot now"
}

run_ddt()
{
	sleep $SLEEP
	sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "cd /root/2023WW23/ && ./clkv run -p spr -o tdx.$(uname -r) -x 'scenario=tdx_guest_bat_tests'"
	sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "cd /root/2023WW23/ && ./clkv run -p spr -o tdx.$(uname -r) -x 'scenario=tdx_guest_func_tests'"
	# can extend here to add more DDT TCs
	# sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "cd /root/2023WW21/ && ./clkv run -p spr -o tdx.$(uname -r) -x 'nl=TDX_TC_1,TDX_TC_2'"
	# sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "cd /root/2023WW21/ && ./clkv run -p spr -o tdx.$(uname -r) -x 'scenario=TDX_test_scenario'"
	if [ $? -ne 0 ]; then
		echo "DDT test failed to execute."
		exit 1
	fi
	sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "systemctl reboot now"
}

cd ${SOURCE_PATH}
rm -rf vm_*.log

# step 4
# Bootup legacy VM using TDX SW ingredients and prepare guest image
nohup sh ${SOURCE_PATH}/qemu.legacy.sh "$KERNEL_IMAGE" > vm_legacy.log &
prepare_guest_image
sleep 10

# step 5
# Bootup TD with 1 CPU and 1G memory
nohup sh "$SOURCE_PATH"/qemu.tdx.sh "$KERNEL_IMAGE" 1 1 1 on > vm_tdx.1_1_1_on.log &
check_lscpu 1
check_mem
run_ddt
sleep 10

# Bootup TD with 1 CPU and 16G memory
nohup sh "$SOURCE_PATH"/qemu.tdx.sh "$KERNEL_IMAGE" 1 1 16 on > vm_tdx.1_1_16_on.log &
check_lscpu 1
check_mem
run_ddt
sleep 10

# Bootup TD with 16 CPU, 2 socket and 16G memory
nohup sh "$SOURCE_PATH"/qemu.tdx.sh "$KERNEL_IMAGE" 16 2 16 on > vm_tdx.16_2_16_on.log &
check_lscpu 16
check_mem
run_ddt
sleep 10

# Bootup TD with 16 CPU, 2 socket and 96G memory
nohup sh "$SOURCE_PATH"/qemu.tdx.sh "$KERNEL_IMAGE" 16 2 96 on > vm_tdx.16_2_96_on.log &
check_lscpu 16
check_mem
run_ddt
sleep 10

# Bootup TD with 64 CPU, 8 socket and 96G memory
nohup sh "$SOURCE_PATH"/qemu.tdx.sh "$KERNEL_IMAGE" 64 8 96 on > vm_tdx.64_8_96_on.log &
check_lscpu 64
check_mem
run_ddt
sleep 10

# Bootup TD with 16 CPU, 2 socket and 16G memory with debug OFF
nohup sh "$SOURCE_PATH"/qemu.tdx.sh "$KERNEL_IMAGE" 16 2 16 off > vm_tdx.16_2_16_off.log &
check_lscpu 16
check_mem
run_ddt
sleep 10

# Check the existence of /dev/tdx_guest
nohup sh "$SOURCE_PATH"/qemu.tdx.sh "$KERNEL_IMAGE" 16 2 16 on &
check_attest_dev
sleep 10

# Check lazy accept
nohup sh "$SOURCE_PATH"/qemu.tdx.sh "$KERNEL_IMAGE" 16 2 16 on &
check_lazy_accept
sleep 10

# ebizzy test in TD guest
nohup sh "$SOURCE_PATH"/qemu.tdx.sh "$KERNEL_IMAGE" 16 2 16 on &
check_ebizzy
sleep 10
