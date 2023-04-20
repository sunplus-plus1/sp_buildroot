#!/bin/bash
if [ "${DEBUG}" == "y" ]; then set -x; fi

do_umount() {
	mountpoint -q ${ROOT_DIR_IN} && sudo umount ${ROOT_DIR_IN}
	mountpoint -q ${BOOT_DIR_IN} && sudo umount ${BOOT_DIR_IN}
	mountpoint -q ${FAT_IMG_DIR} && sudo umount ${FAT_IMG_DIR}
	mountpoint -q ${ROOT_IMG_DIR} && sudo umount ${ROOT_IMG_DIR}
}
# trap do_umount INT
trap do_umount EXIT

do_int() {
	exit
}
trap do_int INT

RESRC_DIR=build/tools/sdcard_boot
MKFS="sudo mke2fs"
RESIZE=resize2fs
OUTPATH=.
ISBUILDSRC=$1
FAT_FILE_IN=$2
ROOT_IMG_IN=$3
KERNEL_DIR=$4
NATIVE_ROOTFS=$5
ROOT_DIR_IN=disk
BOOT_DIR_IN=boot
FAT_IMG_DIR=fat
ROOT_IMG_DIR=image
ROOT_IMG=rootfs.img
OUT_FILE=$OUTPATH/ISP_SD_BOOOT.img
FAT_IMG_OUT=fat.img
NONOS_IMG=a926.img

mkdir -p ${ROOT_DIR_IN}
mkdir -p ${BOOT_DIR_IN}
mkdir -p ${FAT_IMG_DIR}
mkdir -p ${ROOT_IMG_DIR}

if [ "${ISBUILDSRC}" == "y" ]; then
    KERNEL_DIR=SP7021/linux/rootfs/initramfs/disk/lib/modules
	RESRC_DIR=SP7021/${RESRC_DIR}
else 
	extract_filename=`ls -d ${KERNEL_DIR}*`
	if [ "${extract_filename}" != "${KERNEL_DIR}" ]; then
		mv ${extract_filename} ${KERNEL_DIR}
	fi
	if [ -f "${FAT_FILE_IN}/rc.sdcardboot" ]; then
		RESRC_DIR=${FAT_FILE_IN}
	fi
fi

if [ -f "${FAT_FILE_IN}/ISP_SD_BOOOT.img" ]; then
	rm ${FAT_FILE_IN}/ISP_SD_BOOOT.img
fi

# Size of FAT32 partition size (unit: M)
FAT_IMG_SIZE_M=64

# Block size is 512 bytes for sfdisk and FAT32 sector is 1024 bytes
BLOCK_SIZE=512
FAT_SECTOR=1024

# fat.img offset 1M for EFI
seek_offset=1024
seek_bs=1024

# prepare rootfs
# tar -xf ${ROOT_IMG} -C ${ROOT_DIR_IN}
DISKLABEL_EXT4=
DISKLABEL_FAT=
KMODULE=`ls  ${KERNEL_DIR} | grep "5\."`

if [ "${NATIVE_ROOTFS}" == "1" ]; then
	BOOT_DIR_IN=${FAT_FILE_IN}
	sudo mount -t ext4 ${ROOT_IMG_IN} ${ROOT_DIR_IN}
else
	FAT_IMG_SIZE_M=256
	fdisk -lu ${ROOT_IMG_IN}
	DISKLABEL_EXT4="-L writable"
	DISKLABEL_FAT="-n system-boot"
	FAT32_SLBA=`fdisk -lu ${ROOT_IMG_IN} | grep FAT32 | awk '{print $3}'`
	LINUX_SLBA=`fdisk -lu ${ROOT_IMG_IN} | grep Linux | awk '{print $2}'`
	LINUX_SPOS=$((${LINUX_SLBA}*512))
	FAT32_SPOS=$((${FAT32_SLBA}*512))
	sudo mount -t vfat -o loop,rw,sync,offset=${FAT32_SPOS} ${ROOT_IMG_IN} ${BOOT_DIR_IN}
fi

if [ "$?" != "0" ]; then
    exit 1
fi

# Check file
if [ -f $OUT_FILE ]; then
	rm -rf $OUT_FILE
fi

if [ ! -d $FAT_FILE_IN ]; then
	echo "Error: $FAT_FILE_IN doesn't exist!"
	exit 1
fi

if [ ! -d $ROOT_DIR_IN ]; then
	echo "Error: $WORK_DIR doesn't exist!"
	exit 1
fi

# Calculate parameter.
partition_size_1=$(($FAT_IMG_SIZE_M*1024*1024))

# Check size of FAT32 partition.
rm -f "$FAT_IMG_OUT"

sz=`du -sb $FAT_FILE_IN | cut -f1`
if [ $sz -gt $partition_size_1 ]; then
	echo "Size of '$FAT_FILE_IN' (${sz} bytes) is too larger."
	echo "Please modify FAT_IMG_SIZE_M (${partition_size_1} bytes)."
	exit 1;
fi

if [ -x "$(command -v mkfs.fat)" ]; then
	echo '###### do mkfs.fat cmd ########'
	mkfs.fat -F 32 ${DISKLABEL_FAT} -C "$FAT_IMG_OUT" "$(($partition_size_1/$FAT_SECTOR))"
	if [ $? -ne 0 ]; then
		exit 1
	fi
else
	if [ -x "$(command -v mkfs.vfat)" ]; then
		echo '###### do mkfs.vfat cmd ########'
		mkfs.vfat -F 32 -n ${DISKLABEL_FAT} -C "$FAT_IMG_OUT" "$(($partition_size_1/$FAT_SECTOR))"
		if [ $? -ne 0 ]; then
			exit
		fi
	else
		echo "No mkfs.fat and mkfs.vfat cmd, please install it!"
		exit 1
	fi
fi

# mount fat.img and copy boot files to it

sudo mount -t vfat ${FAT_IMG_OUT} ${FAT_IMG_DIR}
if [ "$?" != "0" ]; then
    exit  1
fi

sudo cp -r ${BOOT_DIR_IN}/* ${FAT_IMG_DIR}
sudo cp "$FAT_FILE_IN/ISPBOOOT.BIN" "$FAT_FILE_IN/uEnv.txt" "$FAT_FILE_IN/uImage" "$FAT_FILE_IN/u-boot.img" ${FAT_IMG_DIR}
sudo umount ${FAT_IMG_DIR}

# Offset boot partition (FAT32)
dd if="$FAT_IMG_OUT" of="$OUT_FILE" bs="$seek_bs" seek="$seek_offset"
rm -f "$FAT_IMG_OUT"

if [ "${NATIVE_ROOTFS}" != "1" ]; then
	sudo umount ${BOOT_DIR_IN}
	sudo mount -t ext4 -o loop,rw,sync,offset=${LINUX_SPOS} ${ROOT_IMG_IN} ${ROOT_DIR_IN}	
fi

if [ "$?" != "0" ]; then
    exit 1
fi

# Calculate size of root partition (assume 40% + 20MB overhead).
sz=`sudo du -sb $ROOT_DIR_IN | cut -f1`
sz=$((sz*14/10))
partition_size_2=$(((sz/1024/1024)+500))

while :
do
	echo ""
	read -p "rootfs size (${partition_size_2}M), do you want to expand the capacity of rootfs? (M)" ROOTFS_SIZE

	if [ "${ROOTFS_SIZE}" == "" ] || [ "${ROOTFS_SIZE}" -lt "${partition_size_2}" ]; then
		ROOTFS_SIZE=${partition_size_2}
		break
	else
		# check size string is only number
		ROOTFS_SIZE=`echo ${ROOTFS_SIZE} | grep -E "^[0-9]+$"`
		if [ "${ROOTFS_SIZE}" != "" ]; then
			break
		fi
	fi
done

echo -e "\n>>>>> set rootfs size to ${ROOTFS_SIZE}M\n"

# echo '###### do mke2fs cmd (mke2fs version needs to bigger than 1.45.1) ########'
rm -f "$ROOT_IMG"
$MKFS -t ext4 -b 4096 ${DISKLABEL_EXT4} -d "$ROOT_DIR_IN" "$ROOT_IMG" "$((ROOTFS_SIZE))M"
if [ $? -ne 0 ]; then
	exit 1
fi

# Create root partition (ext4)
# Copy 'rc.sdcardboot' to '/etc/init.d' of root partition.

sudo mount -t ext4 ${ROOT_IMG} ${ROOT_IMG_DIR}

sudo chmod 777 ${ROOT_IMG_DIR}/bin/busybox
RC_SDCARDBOOTDIR=${ROOT_IMG_DIR}/etc/init.d
RC_SDCARDBOOTFILE=${RESRC_DIR}/rc.sdcardboot

sudo cp -rf $RC_SDCARDBOOTFILE $RC_SDCARDBOOTDIR
sudo cp -rf ${KERNEL_DIR}/${KMODULE}  ${ROOT_IMG_DIR}/lib/modules/

if [ "${NATIVE_ROOTFS}" != "1" ]; then
	mktools/adduser.sh ${ROOT_IMG_DIR}
fi

sudo umount ${ROOT_IMG_DIR}

# Resize to minimum + 10%. resize2fs version needs to bigger than 1.45.1.
# partition_sz_2=`$RESIZE -P $ROOT_IMG | cut -d: -f2`
# partition_sz_2=$((partition_sz_2*11/10+1))
# $RESIZE $ROOT_IMG $partition_sz_2
# partition_sz_2=`wc -c ${ROOT_IMG} | awk '{print $1}'`
# Offset root partition (ext4)
dd if="$ROOT_IMG" of="$OUT_FILE" bs="$seek_bs" seek="$(($seek_offset+$partition_size_1/$seek_bs))"

# Create the partition info
partition_size_2=`du -sb $ROOT_IMG | cut -f1`
partition_size_2=$(((partition_size_2+65535)/65536))
partition_size_2=$((partition_size_2*65536))
echo '###### do sfdisk cmd (sfdisk version need to bigger than 2.27.1) ########'
if [ -x "$(command -v sfdisk)" ]; then
	sfdisk -v
	printf "type=b, size=$(($partition_size_1/$BLOCK_SIZE))
		type=83, size=$(($partition_size_2/$BLOCK_SIZE))" |
	sfdisk "$OUT_FILE"
else
	echo "no sfdisk cmd, please install it"
	exit 1
fi

echo -e "\n>>> saved to `pwd`/ISP_SD_BOOOT.img"

rm -f "$ROOT_IMG"
