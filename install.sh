
BUILDROOTPATH=

if [ "$1" == "DEBUG" ]; then
    set -x
fi

## download buildroot 2022.11
BUILDROOT_SITE=https://buildroot.org/downloads/buildroot-2022.11.tar.xz
BR_FILE_XZ=$(basename -- "${BUILDROOT_SITE}")
BR_FILE="${BR_FILE_XZ%.*.*}"
CURRENT_DIR=`pwd`
BUILDROOTPATH=${CURRENT_DIR}

if [ ! -f "${BR_FILE_XZ}" ]; then
    echo -e "\n>>> download buildroot ..."
    wget --passive-ftp -nd -t 3 ${BUILDROOT_SITE}
    echo -e "\n>>> done"
fi

if [ ! -d "${BUILDROOTPATH}/${BR_FILE}" ]; then
    while read -p "Which path to extract to? (${CURRENT_DIR}) " -r BUILDROOTPATH; do
        if [ "${BUILDROOTPATH}" == "" ] || [ "${BUILDROOTPATH}" == "y" ]; then
            BUILDROOTPATH=${CURRENT_DIR}
            break
        fi
        if [ -d "${BUILDROOTPATH}" ]; then
            break
        fi
    done
    tar -xf ${BR_FILE_XZ} -C ${BUILDROOTPATH}        
fi

BUILDROOTPATH=${BUILDROOTPATH}/${BR_FILE}

if [ ! -d "${BUILDROOTPATH}" ]; then
    echo "${BUILDROOTPATH} doesn't existes!"
    exit 1
fi

## copy all defconfig to ../configs directory

defconfigs=`ls *_defconfig`

if [ "${defconfigs}" == "" ]; then 
    exit 0
fi

CONFIGSDIR=${BUILDROOTPATH}/configs
for((i=0; i<${#defconfigs[@]}; i++))
do
    cp ${defconfigs[i]} ${CONFIGSDIR}
done

PACAKEGE_DIR=${BUILDROOTPATH}/package
SPSDK_PACKEAGE_DIR=${PACAKEGE_DIR}/sp_imb

mkdir -p ${SPSDK_PACKEAGE_DIR}

## copy all script except install.sh to package directory

SCRIPTS=`ls *.sh | grep -v 'install.sh'`

for((i=0; i<${#SCRIPTS[@]}; i++))
do
    cp ${SCRIPTS[i]} ${SPSDK_PACKEAGE_DIR}
done

## copy sp_imb.mk and Config.in to package directory

cp Config.in sp_imb.mk ${SPSDK_PACKEAGE_DIR}

## check Config.in of sp_imb whether is in package Config.in 

findstr=`sed -n '/sp_imb/=' ${PACAKEGE_DIR}/Config.in`

if [ "${findstr}" != "" ]; then
    echo "done."
    exit 0
fi

## add sp_imb Config.in to root Config.in

findstr=`sed -n '/endmenu/=' ${PACAKEGE_DIR}/Config.in`
str=($(echo $findstr | tr " " "\n"))  

for i in "${str[@]}"
do     
    INSERTLINE=$(( i-1 ))
done

sed -i "${INSERTLINE}i source \"package/sp_imb/Config.in\"\n" ${PACAKEGE_DIR}/Config.in

echo "done."
exit 0