#!/bin/bash
if [ "${DEBUG}" == "y" ]; then set -x; fi

do_umount() {
	mountpoint -q ${ARM_ROOTFS}/dev && sudo umount ${ARM_ROOTFS}/dev
	mountpoint -q ${ARM_ROOTFS}/proc && sudo umount ${ARM_ROOTFS}/proc
	mountpoint -q ${ARM_ROOTFS}/sys && sudo umount ${ARM_ROOTFS}/sys
}
# trap do_umount INT
trap do_umount EXIT

do_int() {
	exit
}
trap do_int INT

ARM_ROOTFS=$1

if [ ! -f "${ARM_ROOTFS}/usr/bin/qemu-aarch64-static" ]; then
  read -p "Do you want to add user? (y/n)" NEWUSER
  if [ "${NEWUSER}" == "" ] || [ "${NEWUSER}" != "y" ]; then
    echo -e "\n"
    exit 0
  fi
  echo -e "\n>>>>> Add user/password\n"
  read -p "User: " USERNAME
  read -s -p "Password: " PASSWORD
  echo ""
  read -s -p "Retype password: " RPASSWORD

  if [ "${USERNAME}" != "" ]; then
    sudo cp /usr/bin/qemu-aarch64-static ${ARM_ROOTFS}/usr/bin/
    sudo mount -o bind /dev     ${ARM_ROOTFS}/dev
    sudo mount -o bind /proc    ${ARM_ROOTFS}/proc
    sudo mount -o bind /sys     ${ARM_ROOTFS}/sys
    echo -e "adduser ${USERNAME}\n${PASSWORD}\n${RPASSWORD}\n\n\n\n\n\ny\n" | sudo chroot ${ARM_ROOTFS}  /bin/bash
    echo -e "usermod -aG sudo ${USERNAME}" | sudo chroot ${ARM_ROOTFS}  /bin/bash
    if [ -d "/etc/cloud" ]; then
      echo -e "touch /etc/cloud/cloud-init.disabled" | sudo chroot ${ARM_ROOTFS}  /bin/bash
    fi
  else
    echo ">>>>> use default"
  fi
fi

#echo -e "usermod -aG sudo t1" | sudo chroot writable  /bin/bash
