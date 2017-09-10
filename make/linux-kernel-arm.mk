#
# KERNEL
#
KERNEL_VER             = 4.10.12
KERNEL_DATE            = 20170524
KERNEL_TYPE            = hd51
KERNEL_SRC             = linux-$(KERNEL_VER)-arm.tar.gz
KERNEL_CONFIG          = defconfig
KERNEL_DIR             = $(BUILD_TMP)/linux-$(KERNEL_VER)
#
# Todo: findkerneldevice.py

DEPMOD = $(HOST_DIR)/bin/depmod

#
# Patches Kernel
#
KERNEL_PATCHES = \
		armbox/TBS-fixes-for-4.10-kernel.patch \
		armbox/0001-Support-TBS-USB-drivers-for-4.6-kernel.patch \
		armbox/0001-TBS-fixes-for-4.6-kernel.patch \
		armbox/0001-STV-Add-PLS-support.patch \
		armbox/0001-STV-Add-SNR-Signal-report-parameters.patch \
		armbox/blindscan2.patch \
		armbox/0001-stv090x-optimized-TS-sync-control.patch \
		armbox/reserve_dvb_adapter_0.patch \
		armbox/blacklist_mmc0.patch

#
# KERNEL
#
$(ARCHIVE)/$(KERNEL_SRC):
	$(WGET) http://source.mynonpublic.com/gfutures/$(KERNEL_SRC)

$(D)/kernel.do_prepare: $(ARCHIVE)/$(KERNEL_SRC) $(PATCHES)/armbox/$(KERNEL_CONFIG)
	rm -rf $(KERNEL_DIR)
	@echo
	@echo "Starting Kernel build"
	@echo "====================="
	@echo
	$(UNTAR)/$(KERNEL_SRC)
	set -e; cd $(KERNEL_DIR); \
	for i in $(KERNEL_PATCHES); do \
		echo -e "$(TERM_RED)Applying Patch:$(TERM_NORMAL) $$i"; \
		$(PATCH)/$$i; \
	done
	echo -e "Patching $(TERM_GREEN_BOLD)kernel$(TERM_NORMAL) completed."
	$(SILENT)install -m 644 $(PATCHES)/armbox/$(KERNEL_CONFIG) $(KERNEL_DIR)/.config
	sed -i "s#^\(CONFIG_EXTRA_FIRMWARE_DIR=\).*#\1\"$(BASE_DIR)/integrated_firmware\"#" $(KERNEL_DIR)/.config
	-rm $(KERNEL_DIR)/localversion*
	$(SILENT)echo "$(KERNEL_STM_LABEL)" > $(KERNEL_DIR)/localversion-stm
ifeq ($(OPTIMIZATIONS), $(filter $(OPTIMIZATIONS), kerneldebug debug))
	$(SILENT)echo "Configuring kernel for debug."
	$(SILENT)grep -v "CONFIG_PRINTK" "$(KERNEL_DIR)/.config" > $(KERNEL_DIR)/.config.tmp
	cp $(KERNEL_DIR)/.config.tmp $(KERNEL_DIR)/.config
	$(SILENT)echo "CONFIG_PRINTK=y" >> $(KERNEL_DIR)/.config
	$(SILENT)echo "# CONFIG_PRINTK_TIME is not set" >> $(KERNEL_DIR)/.config
endif
	@touch $@

$(D)/kernel.do_compile: $(D)/kernel.do_prepare
	$(SET) -e; cd $(KERNEL_DIR); \
		$(MAKE) -C $(KERNEL_DIR) ARCH=arm oldconfig
#		$(MAKE) -C $(KERNEL_DIR) ARCH=arm CROSS_COMPILE=$(TARGET)- zImage modules CONFIG_DEBUG_SECTION_MISMATCH=y
		$(MAKE) -C $(KERNEL_DIR) ARCH=arm CROSS_COMPILE=$(TARGET)- zImage modules
		$(MAKE) -C $(KERNEL_DIR) ARCH=arm CROSS_COMPILE=$(TARGET)- DEPMOD=$(DEPMOD) INSTALL_MOD_PATH=$(TARGET_DIR) modules_install
	@touch $@

$(D)/kernel: $(D)/bootstrap $(D)/kernel.do_compile
	$(SILENT)install -m 644 $(KERNEL_DIR)/arch/arm/boot/zImage $(BOOT_DIR)/vmlinux.ub
	$(SILENT)install -m 644 $(KERNEL_DIR)/vmlinux $(TARGET_DIR)/boot/vmlinux-arm-$(KERNEL_VER)
	$(SILENT)install -m 644 $(KERNEL_DIR)/System.map $(TARGET_DIR)/boot/System.map-arm-$(KERNEL_VER)
	$(SILENT)cp $(KERNEL_DIR)/arch/arm/boot/zImage $(TARGET_DIR)/boot/
	rm $(TARGET_DIR)/lib/modules/$(KERNEL_VER)/build || true
	rm $(TARGET_DIR)/lib/modules/$(KERNEL_VER)/source || true
	$(TOUCH)

$(D)/kernel-headers: $(D)/kernel.do_prepare
	$(START_BUILD)
	$(SILENT)cd $(KERNEL_DIR); \
		install -d $(TARGET_DIR)/usr/include
		cp -a include/linux $(TARGET_DIR)/usr/include
		cp -a include/asm-arm $(TARGET_DIR)/usr/include/asm
		cp -a include/asm-generic $(TARGET_DIR)/usr/include
		cp -a include/mtd $(TARGET_DIR)/usr/include
	$(TOUCH)

kernel-distclean:
	rm -f $(D)/kernel
	rm -f $(D)/kernel.do_compile
	rm -f $(D)/kernel.do_prepare

kernel-clean:
	-$(MAKE) -C $(KERNEL_DIR) clean
	rm -f $(D)/kernel
	rm -f $(D)/kernel.do_compile

#
# Helper
#
kernel.menuconfig kernel.xconfig: \
kernel.%: $(D)/kernel
	$(MAKE) -C $(KERNEL_DIR) ARCH=arm CROSS_COMPILE=$(TARGET)- $*
	@echo ""
	@echo "You have to edit $(PATCHES)/armbox/$(KERNEL_CONFIG) m a n u a l l y to make changes permanent !!!"
	@echo ""
	diff $(KERNEL_DIR)/.config.old $(KERNEL_DIR)/.config
	@echo ""