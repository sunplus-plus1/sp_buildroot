################################################################################
#
# Sunplus image build
#
################################################################################

#!/bin/bash

SP_IMB_BUILD=$(BUILD_DIR)/$(SP_IMB_PKG)
SP_IMB_OUT=$(SP_IMB_BUILD)/out

define download_build_tools
	@cd $(SP_IMB_BUILD); \
	mktools/dlimage.sh \
	$(SP_IMB_DL_DIR) \
	$(SP_IMB_BUILD_FILE) \
	zip \
	$(SP_IMB_BUILD_SITE) \
	git \
	$(SP_IMB_KERNEL_VER)
endef

define download_prebuilt_kernel
	$(SP_IMB_BUILD)/mktools/dlimage.sh \
	$(SP_IMB_DL_DIR) \
	$(SP_IMB_KERNEL_FILE) \
	zip \
	$(SP_IMB_KERNEL_SITE) \
	wget \
	$(SP_IMB_KERNEL_VER)

	@if [ ! -d "$(SP_IMB_BUILD)/$(SP_IMB_KERNEL_FILE)" ]; \
	then \
		$(call MESSAGE,"extract  $($(SP_IMB_DL_DIR)/$(SP_IMB_KERNEL_FILE).zip) ..."); \
		mkdir -p $(SP_IMB_BUILD); \
		unzip $(SP_IMB_DL_DIR)/$(SP_IMB_KERNEL_FILE).zip -d $(SP_IMB_BUILD) ; \
		mv $(SP_IMB_BUILD)/$(SP_IMB_KERNEL_FILE)-master $(SP_IMB_BUILD)/$(SP_IMB_KERNEL_FILE); \
		mv $(SP_IMB_BUILD)/$(SP_IMB_KERNEL_FILE)-main $(SP_IMB_BUILD)/$(SP_IMB_KERNEL_FILE); \
		$(call MESSAGE,"done"); \
	fi

	$(call download_build_tools)
endef

define download_rootfs
	@cd $(SP_IMB_BUILD); \
	mktools/dlimage.sh \
	$(SP_IMB_DL_DIR) \
	$(SP_IMB_ROOTFS_FILE) \
	$(SP_IMB_ROOTFS_FILE_EXT) \
	$(BR2_SP_ROOTFS_REPO_URL) \
	$(SP_IMB_KERNEL_VER)
endef

define build_emmc_rootfs
	@cd $(SP_IMB_BUILD); \
	mktools/mkemmc.sh \
	$(SP_IMB_OUT) \
	$(TOPDIR)/output/images/rootfs.ext2 \
	$(SP_IMB_BUILD_FILE) \
	$(SP_IMB_SDCARD_DIR) \
	"$(SP_IMB_ISP_BOARD)" \
	$(SP_IMB_BOOT_TYPE) \
	$(SP_IMB_BUILD) \
	"$(SP_IMB_SRC_BUILD)"
endef 

define build_sdcard_rootfs
	@cd $(SP_IMB_BUILD); \
	mktools/mksdcard.sh \
	$(SP_IMB_SRC_BUILD) \
	$(SP_IMB_SDCARD_DIR)/boot2linux_SDcard \
	$(TOPDIR)/output/images/rootfs.ext2 \
	$(SP_IMB_KERNEL_FILE) \
	1
endef 

define use_native_rootfs
	$(if $(BR2_SP_BOOT_TYPE_EMMC),$(call build_emmc_rootfs))
	$(if $(BR2_SP_BOOT_TYPE_SDCARD),$(call build_sdcard_rootfs))
endef

define use_ext_rootfs
	$(call download_rootfs)
	
	@cd $(SP_IMB_BUILD); \
	mktools/mkimage.sh \
	$(SP_IMB_DL_DIR) \
	$(SP_IMB_ROOTFS_FILE) \
	$(SP_IMB_ROOTFS_FILE_EXT) \
	$(SP_IMB_BOOT_TYPE) \
	$(SP_IMB_KERNEL_VER) \
	$(SP_IMB_SDCARD_DIR) \
	$(1) \
	$(SP_IMB_SRC_BUILD)
endef

define use_custom_rootfs
	$(if $(SP_IMB_UMT_ROOTFS),$(call use_ext_rootfs,umt))
	$(if $(SP_IMB_RPI_ROOTFS),$(call use_ext_rootfs,rpi))
endef

define build_source
	@cd $(SP_IMB_BUILD); mktools/mksource.sh \
	$(SP_IMB_DL_DIR) \
	$(SP_IMB_SOURCE_SITE) \
	$(SP_IMB_BOOT_TYPE) \
	$(call UPPERCASE,$(SP_IMB_BOARD)) \
	$(SP_IMB_KERNEL_VER) 
endef

define link_mktool
	cd $(SP_IMB_BUILD)/mktools; \
	ln -s ../../../../package/sp_imb/getext.sh getext.sh; \
	ln -s ../../../../package/sp_imb/mkimage.sh mkimage.sh; \
	ln -s ../../../../package/sp_imb/mksdcard.sh mksdcard.sh; \
	ln -s ../../../../package/sp_imb/mksource.sh mksource.sh; \
	ln -s ../../../../package/sp_imb/dlimage.sh dlimage.sh; \
	ln -s ../../../../package/sp_imb/adduser.sh adduser.sh; \
	ln -s ../../../../package/sp_imb/mkemmc.sh mkemmc.sh; \
	cd -
endef

define use_test 
	@echo $(SP_IMB_SRC_BUILD)
endef

sp_build: check_mktool check_qemu_arm64 check_native
	@mkdir -p $(SP_IMB_DL_DIR)
	@mkdir -p $(SP_IMB_OUT)
	$(if $(SP_IMB_SRC_BUILD),$(call build_source),$(call download_prebuilt_kernel))
	$(if $(BR2_SP_TARGET_ROOTFS_NATIVE),$(call use_native_rootfs))
	$(if $(BR2_SP_TARGET_ROOTFS_64_RPI_202209_DESKTOP),$(call use_ext_rootfs,rpi))
	$(if $(BR2_SP_TARGET_ROOTFS_64_RPI_202209_LITE),$(call use_ext_rootfs,rpi))
	$(if $(BR2_SP_TARGET_ROOTFS_32_RPI_K419),$(call use_ext_rootfs,rpi))
	$(if $(BR2_SP_TARGET_ROOTFS_32_UMT_2004_SERVER),$(call use_ext_rootfs,umt))
	$(if $(BR2_SP_TARGET_ROOTFS_32_UMT_2004_DESKTOP),$(call use_ext_rootfs,umt))
	$(if $(BR2_SP_TARGET_ROOTFS_64_UMT_2004_SERVER),$(call use_ext_rootfs,umt))
	$(if $(BR2_SP_TARGET_ROOTFS_64_UMT_2004_DESKTOP),$(call use_ext_rootfs,umt))
	$(if $(BR2_SP_TARGET_ROOTFS_32_UMT_2204_SERVER),$(call use_ext_rootfs,umt))
	$(if $(BR2_SP_TARGET_ROOTFS_32_UMT_2204_DESKTOP),$(call use_ext_rootfs,umt))
	$(if $(BR2_SP_TARGET_ROOTFS_CUSTOM),$(call use_custom_rootfs))

sp_build_native:
	$(if $(BR2_SP_TARGET_ROOTFS_NATIVE),$(call use_native_rootfs))

check_mktool:
	@if [ ! -d $(SP_IMB_BUILD)/mktools ]; then \
		mkdir -p $(SP_IMB_BUILD)/mktools; \
		$(call link_mktool); \
	else \
		if [ ! -f "$(SP_IMB_BUILD)/mktools/dlimage.sh" ]; then \
			$(call link_mktool); \
		fi \
	fi

check_qemu_arm64:
	@if [ ! -f "/usr/bin/qemu-arm-static" ]; then \
		sudo apt install binfmt-support qemu-system qemu-user qemu-user-static; \
	fi

check_native:
	@if [ "$(BR2_SP_TARGET_ROOTFS_NATIVE)" == "y" ]; then \
		echo ">>> build rootfs"; \
		make; \
		echo "<<< build done"; \
	fi

sp_distclean:
	rm -rf $(SP_IMB_DL_DIR)
	rm -rf $(SP_IMB_BUILD)

sp_clean:
	rm -rf $(SP_IMB_BUILD)/SP7021
	rm $(SP_IMB_DL_DIR)/*.download

sp_test:
	@echo SP_IMB_SRC_BUILD=$(SP_IMB_SRC_BUILD)
	@echo SP_IMB_OUT=$(SP_IMB_OUT)
	@echo SP_IMB_BUILD_FILE=$(SP_IMB_BUILD_FILE)
	@echo SP_IMB_SDCARD_DIR=$(SP_IMB_SDCARD_DIR)
	@echo SP_IMB_BUILD=$(SP_IMB_BUILD)
	@echo SP_IMB_BOARD=$(SP_IMB_BOARD)
	@echo SP_IMB_BOOT_TYPE=$(SP_IMB_BOOT_TYPE)
	@echo SP_IMB_ISP_BOARD=$(SP_IMB_ISP_BOARD)

define get_evboard
	ifeq ($(BR2_SP_BOARD_SP7350),y)
	$(1) = sp7350
	$(2) = SP7350
	else ifeq ($(BR2_SP_BOARD_Q645),y)
	$(1) = q645
	$(2) = Q645
	else ifeq ($(BR2_SP_BOARD_BPI_F2S),y)
	$(1) = bpi_f2s
	else ifeq ($(BR2_SP_BOARD_BPI_F2P),y)
	$(1) = bpi_f2p
	else ifeq ($(BR2_SP_BOARD_DEMOV3),y)
	$(1) = demov3
	endif
endef

define get_kernel
	ifeq ($(BR2_SP_LINUX_KERNEL_510),y)
	$(1) = kernel510
	else ifeq ($(BR2_SP_LINUX_BUILD_KERNEL_510),y)
	$(1) = kernel510
	$(2) = y
	else ifeq ($(BR2_SP_LINUX_KERNEL_54),y)
	$(1) = kernel54
	else ifeq ($(BR2_SP_LINUX_BUILD_KERNEL_54),y)
	$(1) = kernel54
	$(2) = y
	else ifeq ($(BR2_SP_LINUX_KERNEL_419),y)
	$(1) = kernel419
	else ifeq ($(BR2_SP_LINUX_BUILD_KERNEL_419),y)
	$(1) = kernel419
	$(2) = y
	endif
endef

define get_boot_type
	ifeq ($(BR2_SP_BOOT_TYPE_EMMC),y)
	$(1) = emmc
	else ifeq ($(BR2_SP_BOOT_TYPE_SDCARD),y)
	$(1) = sdcard
	else
	$(1) = none
	endif
endef

$(eval $(call get_kernel,SP_IMB_KERNEL_VER,SP_IMB_SRC_BUILD))
$(eval $(call get_evboard,SP_IMB_BOARD,SP_IMB_ISP_BOARD))
$(eval $(call get_boot_type,SP_IMB_BOOT_TYPE))

SP_IMB_PKG = sp_imb
SP_IMB_LICENSE = GPL-2.0
SP_IMB_LICENSE_FILES = COPYING
SP_IMB_BUILD_FILE = build
SP_IMB_DL_DIR = $(call qstrip,$(BR2_DL_DIR))/$(SP_IMB_PKG)
SP_IMB_KERNEL_FILE = $(SP_IMB_KERNEL_VER)_$(SP_IMB_BOARD)_img
SP_IMB_KERNEL_SITE = https://github.com/sunplus-plus1/$(SP_IMB_KERNEL_FILE)/archive/refs/heads/master.zip
SP_IMB_BUILD_SITE = https://github.com/sunplus-plus1/build.git
SP_IMB_SOURCE_SITE = https://github.com/sunplus-plus1/SP7021.git
SP_IMB_ROOTFS_FILE_EXT  = $(if $(BR2_SP_ROOTFS_REPO_URL),$(call LOWERCASE, $(shell cd $(SP_IMB_BUILD); mktools/getext.sh `basename $(BR2_SP_ROOTFS_REPO_URL)`)))
SP_IMB_ROOTFS_FILE = $(call qstrip,$(if $(BR2_SP_ROOTFS_REPO_URL), `basename -s .$(SP_IMB_ROOTFS_FILE_EXT) $(BR2_SP_ROOTFS_REPO_URL)`))
SP_IMB_RPI_ROOTFS = $(findstring raspios,$(SP_IMB_ROOTFS_FILE))
SP_IMB_UMT_ROOTFS = $(findstring ubuntu,$(SP_IMB_ROOTFS_FILE))
SP_IMB_SDCARD_DIR = $(if $(BR2_LINUX_PREBUILT_KERNEL),$(SP_IMB_KERNEL_FILE)/$(SP_IMB_BOOT_TYPE),SP7021/out)
