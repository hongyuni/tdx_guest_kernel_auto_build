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
KERNEL_PATH=/home/tdx/intel_next_master

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
  git clone https://github.com/intel-innersource/os.linux.intelnext.kernel.git
  cd -- || exit 1
}

checkout() {
  cd "${KERNEL_PATH}"/os.linux.intelnext.kernel || exit 1
  git checkout master
  git reset --hard origin/master
  echo "start to checkout to latest tag..."
  git fetch --all
  TAG=$(git tag --list --sort=-creatordate | head -1)
  git checkout "${TAG}"
  TAG_VERIFY=$(git describe --tags --exact-match)
  [ "${TAG}" = "${TAG_VERIFY}" ] || exit 1
  echo "checkout to tag:'${TAG}' done..."
  cd -- || exit 1
}

kconfig() {
  cd "${KERNEL_PATH}"/os.linux.intelnext.kernel || exit 1
  #cp "$SOURCE_PATH"/tdx.gold.config .config
  rm -rf config
  TAG_DATE=${TAG#*2023}
  config_source=2023${TAG_DATE}
  wget https://ubit-artifactory-or.intel.com/artifactory/intelnext-or-local/dcg-pss-eywa-release/archive/"$config_source"/config
  cp config .config
  make olddefconfig
  ./scripts/config --enable CONFIG_INTEL_TDX_GUEST --enable CONFIG_VIRT_DRIVERS --enable CONFIG_TDX_GUEST_DRIVER --enable CONFIG_KVM_GUEST --enable CONFIG_UNACCEPTED_MEMORY --enable CONFIG_TSM_REPORTS
  ./scripts/config --enable CONFIG_FUSE_FS --enable CONFIG_VIRTIO_FS --enable CONFIG_VIRTIO_BALLOON --enable CONFIG_VIRTIO_PMEM
  ./scripts/config --enable CONFIG_XFS_SUPPORT_V4 --enable CONFIG_XFS_ONLINE_SCRUB --enable CONFIG_XFS_ONLINE_REPAIR --enable CONFIG_XFS_WARN --enable CONFIG_XFS_DEBUG
  ./scripts/config --set-str CONFIG_LOCALVERSION -"$TAG"
  yes "" | make config
  grep -r "CONFIG_INTEL_TDX_GUEST=y" .config || exit 1
  grep -r "CONFIG_KVM_GUEST=y" .config || exit 1
  grep -r "CONFIG_TDX_GUEST_DRIVER=y" .config || exit 1
  grep -r "CONFIG_UNACCEPTED_MEMORY=y" .config || exit 1
  grep -r "CONFIG_TSM_REPORTS=y" .config || exit 1
  #./scripts/config --set-str CONFIG_LOCALVERSION -"$TAG"
}

compile() {
  cd "${KERNEL_PATH}"/os.linux.intelnext.kernel || exit 1
  rm -rf arch/x86/boot/bzImage
  grep -r "CONFIG_INTEL_TDX_GUEST=y" .config || exit 1
  grep -r "CONFIG_KVM_GUEST=y" .config || exit 1
  grep -r "CONFIG_TDX_GUEST_DRIVER=y" .config || exit 1
  grep -r "CONFIG_UNACCEPTED_MEMORY=y" .config || exit 1
  grep -r "CONFIG_TSM_REPORTS=y" .config || exit 1
  make ARCH=x86_64 CC="ccache gcc" -j"$(nproc)" -C ./
  cp arch/x86/boot/bzImage arch/x86/boot/bzImage."$TAG"
  ln -s -f arch/x86/boot/bzImage."$TAG" bzImage.ddt
  ls -l bzImage.ddt | grep "bzImage.$TAG" || exit 1
}

#set -x

echo "####################################################################"
echo "step 0:"
echo "create $KERNEL_PATH if not exists and git clone from linux-next repo"
echo "####################################################################"
SOURCE_PATH=$(script_path)

# Do the work
# step 0
[ ! -d "$KERNEL_PATH"/os.linux.intelnext.kernel ] && clone

echo "####################################################################"
echo "step 1:"
echo "git checkout to latest release tag $TAG from above branch"
echo "####################################################################"

# step 1
checkout

echo "####################################################################"
echo "step 2:"
echo "revise all neccessary kconfigs and append tag info $TAG to CONFIG_LOCALVERSION"
echo "kconfig list: CONFIG_INTEL_TDX_GUEST=y CONFIG_KVM_GUEST=y CONFIG_TDX_GUEST_DRIVER=y"
echo "              CONFIG_UNACCEPTED_MEMORY=y CONFIG_TSM_REPORTS=y"
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
echo "pass bzImage.$TAG to LTP-DDT for regression test"
echo "####################################################################"
grep -r "CONFIG_INTEL_TDX_GUEST=y" .config || exit 1
grep -r "CONFIG_KVM_GUEST=y" .config || exit 1
grep -r "CONFIG_TDX_GUEST_DRIVER=y" .config || exit 1
grep -r "CONFIG_UNACCEPTED_MEMORY=y" .config || exit 1
grep -r "CONFIG_TSM_REPORTS=y" .config || exit 1
KERNEL_IMAGE="$KERNEL_PATH"/os.linux.intelnext.kernel/arch/x86/boot/bzImage."${TAG}"

#legacy VM test only
export SSHPASS='123456'
PORT=10088
SLEEP=30

cd ${SOURCE_PATH}
#rm -rf vm_*.log

#prepare_guest_image()
#{
#  sleep $SLEEP
#  sshpass -e ssh -p $PORT root@localhost -o StrictHostKeyChecking=no "poweroff"
#}


# step 4
# Bootup legacy VM using TDX SW ingredients and prepare guest image
#nohup sh ${SOURCE_PATH}/qemu.legacy.sh "$KERNEL_IMAGE" > vm_legacy.log &
#prepare_guest_image
#sleep 10

# step 5
cd 2023WW51
./clkv run -p spr -o hongyu -x "cycle=779 && feature=TDX"
./clkv status -o hongyu
./clkv upload -c 779 -o hongyu
