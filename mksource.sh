#!/bin/bash
if [ "${DEBUG}" == "y" ]; then set -x; fi

CONFIG_ARG=
CONFIG_NUM=
DRAM_PARAM_DIR=boot/draminit/dwc/include/dwc_dram_param.h
XBOOT_CONFIG_FILE_PATH=boot/xboot/.config

select_dram() {
	echo ""	
	echo "select DRAM type:"
	echo "1. NT6AN1024F32AV"
	echo "2. MT53D1024M32D4 (D9WHT)"
	echo "3. MT53E1G32D2_A (D9ZQX)"
	echo "4. MT53E1G32D2_B (D8CJG)"
	echo "5. MT40A2G16SKL_B (D9XQF)"
	echo "6. MT41K512M16VRP (D9ZWN)"
	echo "7. K4AAG165WA"
	echo "8. K4B8G1646D"
	echo ""	
	read -p "Whitch one is on your Board? " sel_dram

	xconfig=
	case "${sel_dram}" in
		"1") xconfig=CONFIG_NT6AN1024F32AV
			;;
		"2") xconfig=CONFIG_MT53D1024M32D4
			;;
		"3") xconfig=CONFIG_MT53E1G32D2_A
			;;
		"4") xconfig=CONFIG_MT53E1G32D2_B
			;;
		"5") xconfig=CONFIG_MT40A2G16SKL_B
			;;
		"6") xconfig=CONFIG_MT41K512M16VRP
			;;
		"7") xconfig=CONFIG_K4AAG165WA
			;;
		"8") xconfig=CONFIG_K4B8G1646D
	esac

	# check default dram type 
	DEFAULT_DRAM=`grep -r "CONFIG_NT6AN1024F32AV" ${XBOOT_CONFIG_FILE_PATH}`
	if [ "${DEFAULT_DRAM}" != "" ]; then
		sed -i -e '/CONFIG_NT6AN1024F32AV/d' ${XBOOT_CONFIG_FILE_PATH} 
	fi

	# remove last dram type setting 
	sed -i -e '/buildroot added/,+2d' ${XBOOT_CONFIG_FILE_PATH} 
	
	# add new dram type setting
	dramstring="# buildroot added\n${xconfig}=y\n"
	echo -e "# buildroot added\n${xconfig}=y\n" >> ${XBOOT_CONFIG_FILE_PATH} 
}

DL_DIR=$1
SOURCE_SITE=$2
BOOT_TYPE=$3
BOARD=$4
KERNEL=$5

NEW_CONFIG="${CONFIG//,/\\n}"

if [ ! -f "${DL_DIR}/SP7021.download" ]; then
	git clone ${SOURCE_SITE}
	if [ "$?" != "0" ]; then
		exit 1
	fi
	cd SP7021
	git submodule update --init --recursive
	if [ "$?" != "0" ]; then
		exit 1
	fi
	git submodule foreach git checkout master
	touch ${DL_DIR}/SP7021.download
else
	cd SP7021
fi

if [ "${KERNEL}" == "kernel510" ]; then
	cd linux/kernel
	git checkout kernel_5.10
	cd -
	cd boot/uboot
	git checkout master
elif [ "${KERNEL}" == "kernel54" ]; then
	cd linux/kernel
	git checkout kernel_5.4
	cd -
	cd boot/uboot
	git checkout uboot_2019
elif [ "${KERNEL}" == "kernel419" ]; then
	cd linux/kernel
	git checkout kernel_4.19
	cd -
	cd boot/uboot
	git checkout uboot_2019
else
	echo "${KERNEL} not supported!"
	exit 1
fi

cd -

if [ "${BOARD}" == "BPI_F2S" ]; then
	CONFIG_ARG=5
elif [ "${BOARD}" == "BPI_F2P " ]; then
	CONFIG_ARG=6
elif [ "${BOARD}" == "DEMOV3" ]; then
	CONFIG_ARG=4
elif [ "${BOARD}" == "Q645" ]; then
	CONFIG_ARG=21
elif [ "${BOARD}" == "SP7350" ]; then
	CONFIG_ARG=31
fi

if [ "${CONFIG_ARG}" -lt "20" ]; then
	if [ "${BOOT_TYPE}" == "sdcard" ]; then
		CONFIG_ARG=${CONFIG_ARG}\\n2\\n
	elif [ "${BOOT_TYPE}" == "emmc" ]; then
		CONFIG_ARG=${CONFIG_ARG}\\n1\\n
	fi
elif [ "${CONFIG_ARG}" -ge "20" ]; then
	if [ "${BOOT_TYPE}" == "sdcard" ]; then
		CONFIG_ARG=${CONFIG_ARG}\\n5\\n
	elif [ "${BOOT_TYPE}" == "emmc" ]; then
		CONFIG_ARG=${CONFIG_ARG}\\n1\\n
	fi
	CONFIG_ARG=${CONFIG_ARG}\\n1\\n
fi

# set rootfs = busybox
CONFIG_ARG=${CONFIG_ARG}1\\n

# make config
if [ "${CONFIG}" == "" ]; then
	if [ ! -f "SP7021.config" ]; then
		echo -e "${CONFIG_ARG}" | make config
	fi
	if [ "`echo $?`" == "0" ]; then
		touch SP7021.config
	fi
elif [ "${CONFIG}" == "y" ]; then
	echo -e "${CONFIG_ARG}" | make config
else
	if [ "${CONFIG}" != "n" ]; then
		echo -e "${NEW_CONFIG}" | make config
	fi
fi

# make
if [ "${COMPILE}" == "y" ] || [ "${COMPILE}" == "" ]; then	
	if [ "${BOARD}" == "Q645" ] || [ "${BOARD}" == "Q654" ]; then \
		select_dram; \
	fi
	make
fi
