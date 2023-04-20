#!/bin/bash

if [ "${DEBUG}" == "y" ]; then set -x; fi

do_umount() {
	mountpoint -q ${IMGDIR} && sudo umount ${IMGDIR}
    if [ "${LOOP}" != "" ]; then sudo losetup -d > /dev/null 2>&1 ${LOOP}; fi
}
trap do_umount EXIT

do_int() {
	exit
}
trap do_int INT

get_extracted_filename() {
    fname=
    for i in `ls`
    do
    if [[ $i =~ $1* ]]; then
        fname=$i
        break
    fi
    done
    echo ${fname}
}

ROOTFS=$(get_extracted_filename $2) 
if [ "${ROOTFS}" == "" ]; then
    ROOTFS=$2
fi

DLPATH=$1
ROOTFSEXT=$3
BOOTYPE=$4
KERNEL_VER=$5
KERNEL_DIR=$6/..
SDCARD_DIR=$6/boot2linux_SDcard
IMGTYPE=$7
ISBUILDSRC=$8
IMGDIR=image

mkdir -p ${IMGDIR}

if [ "${ISBUILDSRC}" == "y" ]; then
    KERNEL_DIR=${KERNEL_DIR}/linux/rootfs/initramfs/disk/lib/modules
fi

if [ -f "${ROOTFS}" ]; then
    rm ${ROOTFS}
fi

echo ">>> extract ..."
if [ "${ROOTFSEXT}" == "xz" ]; then 
    xz -d ${DLPATH}/${ROOTFS}.${ROOTFSEXT} -c > ${ROOTFS}
elif [ "${ROOTFSEXT}" == "zip" ]; then 
    unzip ${DLPATH}/${ROOTFS}.${ROOTFSEXT} -d .
    ROOTFS=$(get_extracted_filename ${ROOTFS}) 
fi
echo ">>> done";

sudo fdisk -lu ${ROOTFS}

if [ "${IMGTYPE}" == "rpi" ]
then
    FAT32_SLBA=`sudo fdisk -lu ${ROOTFS} | grep FAT32 | awk '{print $2}'`
    LINUX_SLBA=`sudo fdisk -lu ${ROOTFS} | grep Linux | awk '{print $2}'`
elif [ "${IMGTYPE}" == "umt" ]
then
    FAT32_SLBA=`sudo fdisk -lu ${ROOTFS} | grep FAT32 | awk '{print $3}'`
    LINUX_SLBA=`sudo fdisk -lu ${ROOTFS} | grep Linux | awk '{print $2}'`
    if [ 1 ]
    then
        mktools/mksdcard.sh \
        0 \
        ${SDCARD_DIR} \
        ${ROOTFS} \
        ${KERNEL_DIR} \
        0
        exit 0
    fi
fi

LOOP=`sudo losetup -f`

FAT32_SPOS=$((${FAT32_SLBA}*512))
LINUX_SPOS=$((${LINUX_SLBA}*512))

if [ "$?" != "0" ]; then
    exit 1
fi

sudo losetup -o ${FAT32_SPOS} ${LOOP} ${ROOTFS}
sudo mount ${LOOP} ${IMGDIR}

if [ "$?" != "0" ]; then
    echo ">>> mount fail"
    exit 1
fi

echo ">>> copy boot files"

# cp ISPBOOOT.BIN u-boot.img uEnv.txt uImage
sudo cp ${SDCARD_DIR}/{ISPBOOOT.BIN,u-boot.img,uEnv.txt,uImage} ${IMGDIR}
sleep 1

sudo umount ${IMGDIR} 
sudo losetup -d ${LOOP}

if [ "${KERNEL_VER}" != "kernel419" ]; then

    KMODULE=`ls  ${KERNEL_DIR} | grep "5."`
    if [ "${KMODULE}" == "" ]; then
        echo "error: kernel module not found!"
        exit 1
    fi

    echo ">>> copy rootfs files"

    sudo mount -t ext4 -o loop,rw,sync,offset=${LINUX_SPOS} ${ROOTFS} ${IMGDIR}
    if [ "$?" != "0" ]; then
        echo ">>>>> mount fail"
        exit 1
    fi
    sudo cp -r ${KERNEL_DIR}/${KMODULE} ${IMGDIR}/lib/modules/
    sleep 1
    mktools/adduser.sh ${IMGDIR}
    # sudo umount ${IMGDIR} 
fi

echo -e "\n>>> done. saved to `pwd`/${ROOTFS}"

