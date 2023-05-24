#!/bin/bash
if [ "${DEBUG}" == "y" ]; then set -x; fi

HOSTNAME=`hostname`
SUDO=sudo

if [ -f "/.podmanenv" ]; then
  SUDO=
fi

do_umount() {
	mountpoint -q ${ARM_ROOTFS}/dev && ${SUDO} umount ${ARM_ROOTFS}/dev
	mountpoint -q ${ARM_ROOTFS}/proc && ${SUDO} umount ${ARM_ROOTFS}/proc
	mountpoint -q ${ARM_ROOTFS}/sys && ${SUDO} umount ${ARM_ROOTFS}/sys
}
# trap do_umount INT
trap do_umount EXIT

do_int() {
	exit
}
trap do_int INT

ARM_ROOTFS=$1

if [ ! -f "${ARM_ROOTFS}/usr/bin/qemu-aarch64-static" ]; then
  
  while read -p "Do you want to add user? (y/n)" -r NEWUSER; do
      case $NEWUSER in
          y) echo -e "\n"; break ;;
          n) exit 0 ;;
      esac
  done
  echo -e "\n>>>>> Add user/password\n"
  read -p "User: " USERNAME
  read -s -p "Password: " PASSWORD
  echo ""
  read -s -p "Retype password: " RPASSWORD

  if [ "${USERNAME}" != "" ]; then
    ${SUDO} cp /usr/bin/qemu-aarch64-static ${ARM_ROOTFS}/usr/bin/
    ${SUDO} mount -o bind /dev     ${ARM_ROOTFS}/dev
    ${SUDO} mount -o bind /proc    ${ARM_ROOTFS}/proc
    ${SUDO} mount -o bind /sys     ${ARM_ROOTFS}/sys
    echo -e "adduser ${USERNAME}\n${PASSWORD}\n${RPASSWORD}\n\n\n\n\n\ny\n" | ${SUDO} chroot ${ARM_ROOTFS}  /bin/bash
    echo -e "usermod -aG ${SUDO} ${USERNAME}" | ${SUDO} chroot ${ARM_ROOTFS}  /bin/bash
    if [ -d "/etc/cloud" ]; then
      echo -e "touch /etc/cloud/cloud-init.disabled" | ${SUDO} chroot ${ARM_ROOTFS}  /bin/bash
    fi
  else
    echo ">>>>> use default"
  fi
fi

#echo -e "usermod -aG ${SUDO} t1" | ${SUDO} chroot writable  /bin/bash
