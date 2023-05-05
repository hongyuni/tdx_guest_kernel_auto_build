# tdx_guest_kernel_auto_build
a simple work flow to verify based on latest release tag of kernel source code

current target is mainline linux_next repo: https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git

step 0: create $KERNEL_PATH if not exists and git clone from linux-next repo

step 1: git checkout to latest release tag $TAG from above branch

step 2: ./scripts/config revise CONFIG_INTEL_TDX_GUEST=y and append tag info $TAG to CONFIG_LOCALVERSION

step 3: compile kernel and cp it as bzImage.$TAG

step 4: bootup legacy VM to prepare guest image

step 5: pass above kernel bzImage to td_guest_boot.sh for TD guest booting test
