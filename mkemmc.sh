#!/bin/bash
if [ "${DEBUG}" == "y" ]; then set -x; fi

do_int() {
	exit
}
trap do_int INT

OUTPATH=.
SP_IMB_OUT=$1
ROOT_IMG_IN=$2
SP_IMB_BUILD_FILE=$3
SP_IMB_SDCARD_DIR=$4
SP_IMB_ISP_BOARD=$5
SP_IMB_BOOT_TYPE=$6
SP_IMB_BUILD=$7
ISBUILDSRC=$8

if [ "${ISBUILDSRC}" == "y" ]; then
	cp ${ROOT_IMG_IN} SP7021/out/rootfs.img
	cd SP7021/out
	./isp.sh ${SP_IMB_BOOT_TYPE^^} ${SP_IMB_ISP_BOARD}
	if [ "$?" == "0" ]; then
		echo -e "Saved to ${SP_IMB_BUILD}/SP7021/out/ISPBOOOT.BIN\n"
	fi
else 
	rm "${SP_IMB_BUILD_FILE}/tools/isp/isp"
	make -C ${SP_IMB_BUILD_FILE}/tools/isp CHIP=${SP_IMB_ISP_BOARD}

	if [ ! -f "${SP_IMB_OUT}/isp.sh" ];
	then 
		cp ${SP_IMB_BUILD}/${SP_IMB_BUILD_FILE}/isp.sh ${SP_IMB_OUT}
		sed -i 's/cat /echo -ne "\r" #cat /g' ${SP_IMB_OUT}/isp.sh
	fi

	cp -r ${SP_IMB_BUILD}/${SP_IMB_SDCARD_DIR}/* ${SP_IMB_OUT}
	cp ${ROOT_IMG_IN} ${SP_IMB_OUT}/rootfs.img

	cd ${SP_IMB_OUT}
	export PATH=$PATH:${SP_IMB_BUILD_FILE}/tools/isp; \
	./isp.sh ${SP_IMB_BOOT_TYPE^^} ${SP_IMB_ISP_BOARD}

	if [ "$?" == "0" ]; then
		echo -e "Saved to ${SP_IMB_OUT}/ISPBOOOT.BIN\n"
	fi
fi

