#!/bin/bash

if [ "${DEBUG}" == "y" ]; then set -x; fi

SDK_DL_DIR=$1
SDK_ROOTFS_FILE=$2
SDK_ROOTFS_FILE_EXT=$3
ROOTFS_REPO_URL=$4
DL_METHOD=$5
SP_IMB_KERNEL_VER=$6

if [ ! -f "${SDK_DL_DIR}/${SDK_ROOTFS_FILE}.download" ]; then
    echo ">>>>> downloading ..."

    if [ "${DL_METHOD}" == "wget" ]; then
        wget --passive-ftp -nd -t 3 -O ${SDK_DL_DIR}/${SDK_ROOTFS_FILE}.${SDK_ROOTFS_FILE_EXT} ${ROOTFS_REPO_URL} 
    elif [ "${DL_METHOD}" == "git" ]; then
        if [ ! -d "${SDK_ROOTFS_FILE}" ]; then
            git clone ${ROOTFS_REPO_URL}
        fi
    else
        echo "${DL_METHOD} not supportted"
        exit 1
    fi

    if [ $? -eq 0 ]; then 
        touch ${SDK_DL_DIR}/${SDK_ROOTFS_FILE}.download
    else
        echo ">>>>> downloading failed"
        exit 1
    fi 
    echo ">>>>> done ..."
fi

if [ "${SDK_ROOTFS_FILE}" == "build" ]; then
    # check kernel version
    # pre_built has no fip.img 
    cd build; 
    if [ "${SP_IMB_KERNEL_VER}" != "kernel510" ]; then
        git checkout ba51de0b147f213
    else
        git checkout master
    fi
fi
