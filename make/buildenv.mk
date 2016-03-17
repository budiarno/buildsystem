# set up environment for other makefiles
# print '+' before each executed command
# SHELL := $(SHELL) -x

CONFIG_SITE =
export CONFIG_SITE

CCACHE_DIR            = $(HOME)/.ccache-ddt
export CCACHE_DIR

BASE_DIR             := $(shell cd .. && pwd)

ARCHIVE               = $(HOME)/Archive
APPS_DIR              = $(BASE_DIR)/apps
BUILD_TMP             = $(BASE_DIR)/build_tmp
CDK_DIR               = $(BASE_DIR)/cdk
DRIVER_DIR            = $(BASE_DIR)/driver
FLASH_DIR             = $(BASE_DIR)/flash
SOURCE_DIR            = $(BASE_DIR)/source

-include $(CDK_DIR)/config

# default platform...
TARGET               ?= sh4-linux
BOXARCH              ?= sh4

BOOT_DIR              = $(BASE_DIR)/tufsbox/cdkroot-tftpboot
CROSS_BASE            = $(BASE_DIR)/tufsbox/cross
CROSS_DIR             = $(CROSS_BASE)
CONTROL_DIR           = $(BASE_DIR)/pkgs/control
HOSTPREFIX            = $(BASE_DIR)/tufsbox/host
PACKAGE_DIR           = $(BASE_DIR)/pkgs/opkg
RELEASE_DIR           = $(BASE_DIR)/tufsbox/release
PKGPREFIX             = $(BUILD_TMP)/pkg
TARGETPREFIX          = $(BASE_DIR)/tufsbox/cdkroot

CUSTOM_DIR            = $(CDK_DIR)/custom
SCRIPTS_DIR           = $(CDK_DIR)/scripts
PATCHES               = $(CDK_DIR)/Patches
SKEL_ROOT             = $(CDK_DIR)/root
D                     = $(CDK_DIR)/.deps
# backwards compatibility
DEPDIR                = $(D)

WHOAMI               := $(shell id -un)
#MAINTAINER           ?= $(shell getent passwd $(WHOAMI)|awk -F: '{print $$5}')
MAINTAINER           ?= $(shell whoami)

CCACHE                = /usr/bin/ccache

BUILD                ?= $(shell /usr/share/libtool/config.guess 2>/dev/null || /usr/share/libtool/config/config.guess)

TARGETLIB             = $(TARGETPREFIX)/usr/lib
TARGET_CFLAGS         = -pipe -Os -I$(TARGETPREFIX)/usr/include
TARGET_CPPFLAGS       = $(TARGET_CFLAGS)
TARGET_CXXFLAGS       = $(TARGET_CFLAGS)
TARGET_LDFLAGS        = -Wl,-rpath -Wl,/usr/lib -Wl,-rpath-link -Wl,$(TARGETPREFIX)/usr/lib -L$(TARGETPREFIX)/usr/lib -L$(TARGETPREFIX)/lib
#TARGET_LDFLAGS        = -Wl,-O1 -L$(TARGETLIB) -Wl,-rpath-link,$(TARGETLIB) -L$(TARGETPREFIX)/usr/lib -L$(TARGETPREFIX)/lib
LD_FLAGS              = $(TARGET_LDFLAGS)

VPATH                 = $(D)

PATH                 := $(HOSTPREFIX)/bin:$(CROSS_DIR)/bin:$(PATH):/sbin:/usr/sbin:/usr/local/sbin

PKG_CONFIG            = $(HOSTPREFIX)/bin/$(TARGET)-pkg-config
PKG_CONFIG_PATH       = $(TARGETPREFIX)/usr/lib/pkgconfig

# helper-"functions":
REWRITE_LIBTOOL       = sed -i "s,^libdir=.*,libdir='$(TARGETPREFIX)/usr/lib'," $(TARGETPREFIX)/usr/lib
REWRITE_LIBTOOLDEP    = sed -i -e "s,\(^dependency_libs='\| \|-L\|^dependency_libs='\)/usr/lib,\ $(TARGETPREFIX)/usr/lib,g" $(TARGETPREFIX)/usr/lib
REWRITE_PKGCONF       = sed -i "s,^prefix=.*,prefix='$(TARGETPREFIX)/usr',"
REWRITE_LIBTOOL_OPT   = sed -i "s,^libdir=.*,libdir='$(TARGETPREFIX)/opt/pkg/lib'," $(TARGETPREFIX)/opt/pkg/lib
REWRITE_PKGCONF_OPT   = sed -i "s,^prefix=.*,prefix='$(TARGETPREFIX)/opt/pkg',"

export RM=$(shell which rm) -f

# helper perl
#REWRITE_LIBTOOL       = perl -pi -e "s,^libdir=.*$$,libdir='$(TARGETPREFIX)/usr/lib'," $(TARGETPREFIX)/usr/lib
#REWRITE_LIBTOOLDEP    = perl -pi -e "s, /usr/lib, $(TARGETPREFIX)/usr/lib,g if /^dependency_libs/" $(TARGETPREFIX)/usr/lib
#REWRITE_PKGCONF       = perl -pi -e "s,^prefix=.*$$,prefix=$(TARGETPREFIX)/usr,"

# unpack tarballs, clean up
UNTAR                 = tar -C $(BUILD_TMP) -xf $(ARCHIVE)
REMOVE                = rm -rf $(BUILD_TMP)
RM_PKGPREFIX          = rm -rf $(PKGPREFIX)
PATCH                 = patch -p1 -i $(PATCHES)

#
#
#
OPKG_SH_ENV  = PACKAGE_DIR=$(PACKAGE_DIR)
OPKG_SH_ENV += STRIP=$(TARGET)-strip
OPKG_SH_ENV += MAINTAINER="$(MAINTAINER)"
OPKG_SH_ENV += ARCH=$(BOXARCH)
OPKG_SH_ENV += SOURCE=$(PKG_DIR)
OPKG_SH_ENV += BUILD_TMP=$(BUILD_TMP)
OPKG_SH = $(OPKG_SH_ENV) opkg.sh

# wget tarballs into archive directory
WGET = wget --progress=bar:force --no-check-certificate -t6 -T20 -c -P $(ARCHIVE)

TUXBOX_YAUD_CUSTOMIZE = [ -x $(CUSTOM_DIR)/$(notdir $@)-local.sh ] && KERNEL_VERSION=$(KERNEL_VERSION) && BOXTYPE=$(BOXTYPE) && $(CUSTOM_DIR)/$(notdir $@)-local.sh $(RELEASE_DIR) $(TARGETPREFIX) $(CDK_DIR) $(SOURCE_DIR) $(FLASH_DIR) $(BOXTYPE) || true
TUXBOX_CUSTOMIZE      = [ -x $(CUSTOM_DIR)/$(notdir $@)-local.sh ] && KERNEL_VERSION=$(KERNEL_VERSION) && BOXTYPE=$(BOXTYPE) && $(CUSTOM_DIR)/$(notdir $@)-local.sh $(RELEASE_DIR) $(TARGETPREFIX) $(CDK_DIR) $(BOXTYPE) || true

#
#
#
CONFIGURE_OPTS = \
	--build=$(BUILD) --host=$(TARGET)

BUILDENV = \
	CC=$(TARGET)-gcc \
	CXX=$(TARGET)-g++ \
	LD=$(TARGET)-ld \
	NM=$(TARGET)-nm \
	AR=$(TARGET)-ar \
	AS=$(TARGET)-as \
	RANLIB=$(TARGET)-ranlib \
	STRIP=$(TARGET)-strip \
	OBJCOPY=$(TARGET)-objcopy \
	OBJDUMP=$(TARGET)-objdump \
	LN_S="ln -s" \
	CFLAGS="$(TARGET_CFLAGS)" \
	CPPFLAGS="$(TARGET_CPPFLAGS)" \
	CXXFLAGS="$(TARGET_CXXFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	PKG_CONFIG_PATH="$(PKG_CONFIG_PATH)"

CONFIGURE = \
	test -f ./configure || ./autogen.sh && \
	$(BUILDENV) \
	./configure $(CONFIGURE_OPTS)

MAKE_OPTS := \
	CC=$(TARGET)-gcc \
	CXX=$(TARGET)-g++ \
	LD=$(TARGET)-ld \
	NM=$(TARGET)-nm \
	AR=$(TARGET)-ar \
	AS=$(TARGET)-as \
	RANLIB=$(TARGET)-ranlib \
	STRIP=$(TARGET)-strip \
	OBJCOPY=$(TARGET)-objcopy \
	OBJDUMP=$(TARGET)-objdump \
	LN_S="ln -s" \
	ARCH=sh \
	CROSS_COMPILE=$(TARGET)-

#
# kernel
#
ifeq ($(KERNELDEBUG), debug)
DEBUG_STR          = .debug
else
DEBUG_STR          =
endif

ifeq ($(KERNEL), p0209)
KERNEL_VERSION       = 2.6.32.46_stm24_0209
HOST_KERNEL_REVISION = 8c676f1a85935a94de1fb103c0de1dd25ff69014
P0209                = p0209
endif

ifeq ($(KERNEL), p0211)
KERNEL_VERSION       = 2.6.32.59_stm24_0211
HOST_KERNEL_REVISION = 3bce06ff873fb5098c8cd21f1d0e8d62c00a4903
P0209                = p0211
endif

ifeq ($(KERNEL), p0214)
KERNEL_VERSION       = 2.6.32.61_stm24_0214
HOST_KERNEL_REVISION = 5cf7f6f209d832a4cf645125598f86213f556fb3
P0209                = p0214
endif

ifeq ($(KERNEL), p0215)
KERNEL_VERSION       = 2.6.32.61_stm24_0215
HOST_KERNEL_REVISION = 5384bd391266210e72b2ca34590bd9f543cdb5a3
P0209                = p0215
endif

ifeq ($(KERNEL), p0217)
KERNEL_VERSION       = 2.6.32.61_stm24_0217
HOST_KERNEL_REVISION = b43f8252e9f72e5b205c8d622db3ac97736351fc
P0217                = p0217
endif

split_version=$(subst _, ,$(1))
KERNEL_UPSTREAM    =$(word 1,$(call split_version,$(KERNEL_VERSION)))
KERNEL_STM        :=$(word 2,$(call split_version,$(KERNEL_VERSION)))
KERNEL_LABEL      :=$(word 3,$(call split_version,$(KERNEL_VERSION)))
KERNEL_RELEASE    :=$(subst ^0,,^$(KERNEL_LABEL))
KERNEL_STM_LABEL  := _$(KERNEL_STM)_$(KERNEL_LABEL)
KERNEL_DIR         =$(BUILD_TMP)/linux-sh4-$(KERNEL_VERSION)

#
# image
#
ifeq ($(IMAGE), enigma2)
BUILD_CONFIG       = build-enigma2
else ifeq ($(IMAGE), enigma2-wlandriver)
BUILD_CONFIG       = build-enigma2
WLANDRIVER         = WLANDRIVER=wlandriver
else ifeq ($(IMAGE), neutrino)
BUILD_CONFIG       = build-neutrino
else ifeq ($(IMAGE), neutrino-wlandriver)
BUILD_CONFIG       = build-neutrino
WLANDRIVER         = WLANDRIVER=wlandriver
else
BUILD_CONFIG       = build-neutrino
endif

#
#
#
ifeq ($(MEDIAFW), eplayer3)
EPLAYER3           = 1
else ifeq ($(MEDIAFW), gstreamer)
gstreamer          = 1
else ifeq ($(MEDIAFW), gst-eplayer3)
EPLAYER3           = 1
gst-eplayer3       = 1
else
buildinplayer      = 1
endif

#
# multicom
#
ifeq ($(MULTICOM), multicom324)
MULTICOM324        = multicom324
else
MULTICOM406        = multicom406
endif

#
# player 2
#
ifeq ($(PLAYER), player191)
PLAYER2            = PLAYER191=player191
PLAYER191          = 1
else
PLAYER2            =
endif

#
#
#
DRIVER_PLATFORM   := $(PLAYER2) $(WLANDRIVER)
PLATFORM_CPPFLAGS := $(TARGET_CPPFLAGS) -I$(DRIVER_DIR)/include -I$(APPS_DIR)/tools/libeplayer3/include -I$(KERNEL_DIR)/include
#
ifeq ($(BOXTYPE), ufs910)
KERNEL_PATCHES_24  = $(UFS910_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_UFS910
DRIVER_PLATFORM   += UFS910=ufs910
endif
ifeq ($(BOXTYPE), ufs912)
KERNEL_PATCHES_24  = $(UFS912_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_UFS912
DRIVER_PLATFORM   += UFS912=ufs912
endif
ifeq ($(BOXTYPE), ufs913)
KERNEL_PATCHES_24  = $(UFS913_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_UFS913
DRIVER_PLATFORM   += UFS913=ufs913
endif
ifeq ($(BOXTYPE), ufs922)
KERNEL_PATCHES_24  = $(UFS922_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_UFS922
DRIVER_PLATFORM   += UFS922=ufs922
endif
ifeq ($(BOXTYPE), ufs960)
KERNEL_PATCHES_24  = $(UFC960_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_UFS960
DRIVER_PLATFORM   += UFC960=ufs960
endif
ifeq ($(BOXTYPE), tf7700)
KERNEL_PATCHES_24  = $(TF7700_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_TF7700 --enable-tf7700
DRIVER_PLATFORM   += TF7700=tf7700
endif
ifeq ($(BOXTYPE), hl101)
KERNEL_PATCHES_24  = $(HL101_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_HL101 --enable-hl101
DRIVER_PLATFORM   += HL101=hl101
endif
ifeq ($(BOXTYPE), spark)
KERNEL_PATCHES_24  = $(SPARK_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_SPARK
DRIVER_PLATFORM   += SPARK=spark
endif
ifeq ($(BOXTYPE), spark7162)
KERNEL_PATCHES_24  = $(SPARK7162_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_SPARK7162
DRIVER_PLATFORM   += SPARK7162=spark7162
endif
ifeq ($(BOXTYPE), fortis_hdbox)
KERNEL_PATCHES_24  = $(FORTIS_HDBOX_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_FORTIS_HDBOX
DRIVER_PLATFORM   += FORTIS_HDBOX=fortis_hdbox
endif
ifeq ($(BOXTYPE), hs7110)
KERNEL_PATCHES_24  = $(HS7110_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_HS7110
DRIVER_PLATFORM   += HS7110=hs7110
endif
ifeq ($(BOXTYPE), hs7810a)
KERNEL_PATCHES_24  = $(HS7810A_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_HS7810A
DRIVER_PLATFORM   += HS7810A=hs7810a
endif
ifeq ($(BOXTYPE), hs7119)
KERNEL_PATCHES_24  = $(HS7119_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_HS7119
DRIVER_PLATFORM   += HS7119=hs7119
endif
ifeq ($(BOXTYPE), hs7819)
KERNEL_PATCHES_24  = $(HS7819_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_HS7819
DRIVER_PLATFORM   += HS7819=hs7819
endif
ifeq ($(BOXTYPE), atemio520)
KERNEL_PATCHES_24  = $(ATEMIO520_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_ATEMIO520
DRIVER_PLATFORM   += ATEMIO520=atemio520
endif
ifeq ($(BOXTYPE), atemio530)
KERNEL_PATCHES_24  = $(ATEMIO530_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_ATEMIO530
DRIVER_PLATFORM   += ATEMIO530=atemio530
endif
ifeq ($(BOXTYPE), atevio7500)
KERNEL_PATCHES_24  = $(ATEVIO7500_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_ATEVIO7500
DRIVER_PLATFORM   += ATEVIO7500=atevio7500
endif
ifeq ($(BOXTYPE), octagon1008)
KERNEL_PATCHES_24  = $(OCTAGON1008_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_OCTAGON1008
DRIVER_PLATFORM   += OCTAGON1008=octagon1008
endif
ifeq ($(BOXTYPE), adb_box)
KERNEL_PATCHES_24  = $(ADB_BOX_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_ADB_BOX --enable-adb_box
DRIVER_PLATFORM   += ADB_BOX=adb_box
endif
ifeq ($(BOXTYPE), ipbox55)
KERNEL_PATCHES_24  = $(IPBOX55_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_IPBOX55
DRIVER_PLATFORM   += IPBOX55=ipbox55
endif
ifeq ($(BOXTYPE), ipbox99)
KERNEL_PATCHES_24  = $(IPBOX99_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_IPBOX99
DRIVER_PLATFORM   += IPBOX99=ipbox99
endif
ifeq ($(BOXTYPE), ipbox9900)
KERNEL_PATCHES_24  = $(IPBOX9900_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_IPBOX9900
DRIVER_PLATFORM   += IPBOX9900=ipbox9900
endif
ifeq ($(BOXTYPE), cuberevo)
KERNEL_PATCHES_24  = $(CUBEREVO_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_CUBEREVO --enable-cuberevo
DRIVER_PLATFORM   += CUBEREVO=cuberevo
endif
ifeq ($(BOXTYPE), cuberevo_mini)
KERNEL_PATCHES_24  = $(CUBEREVO_MINI_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_CUBEREVO_MINI --enable-cuberevo
DRIVER_PLATFORM   += CUBEREVO_MINI=cuberevo_mini
endif
ifeq ($(BOXTYPE), cuberevo_mini2)
KERNEL_PATCHES_24  = $(CUBEREVO_MINI2_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_CUBEREVO_MINI2 --enable-cuberevo
DRIVER_PLATFORM   += CUBEREVO_MINI2=cuberevo_mini2
endif
ifeq ($(BOXTYPE), cuberevo_mini_fta)
KERNEL_PATCHES_24  = $(CUBEREVO_MINI_FTA_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_CUBEREVO_MINI_FTA --enable-cuberevo
DRIVER_PLATFORM   += CUBEREVO_MINI_FTA=cuberevo_mini_fta
endif
ifeq ($(BOXTYPE), cuberevo_250hd)
KERNEL_PATCHES_24  = $(CUBEREVO_250HD_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_CUBEREVO_250HD --enable-cuberevo
DRIVER_PLATFORM   += CUBEREVO_250HD=cuberevo_250hd
endif
ifeq ($(BOXTYPE), cuberevo_2000hd)
KERNEL_PATCHES_24  = $(CUBEREVO_2000HD_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_CUBEREVO_2000HD --enable-cuberevo
DRIVER_PLATFORM   += CUBEREVO_2000HD=cuberevo_2000hd
endif
ifeq ($(BOXTYPE), cuberevo_3000hd)
KERNEL_PATCHES_24  = $(CUBEREVO_3000HD_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_CUBEREVO_3000HD --enable-cuberevo
DRIVER_PLATFORM   += CUBEREVO_3000HD=cuberevo_3000hd
endif
ifeq ($(BOXTYPE), cuberevo_9500hd)
KERNEL_PATCHES_24  = $(CUBEREVO_9500HD_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_CUBEREVO_9500HD --enable-cuberevo
DRIVER_PLATFORM   += CUBEREVO_9500HD=cuberevo_9500hd
endif
ifeq ($(BOXTYPE), vitamin_hd5000)
KERNEL_PATCHES_24  = $(VITAMIN_HD5000_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_VITAMIN_HD5000
DRIVER_PLATFORM   += VITAMIN_HD5000=vitamin_hd5000
endif
ifeq ($(BOXTYPE), sagemcom88)
KERNEL_PATCHES_24  = $(SAGEMCOM88_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_SAGEMCOM88
DRIVER_PLATFORM   += SAGEMCOM88=sagemcom88
endif
ifeq ($(BOXTYPE), arivalink200)
KERNEL_PATCHES_24  = $(ARIVALINK200_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_ARIVALINK200
DRIVER_PLATFORM   += ARIVALINK200=arivalink200
endif
ifeq ($(BOXTYPE), fortis_dp7000)
KERNEL_PATCHES_24  = $(FORTIS_DP7000_PATCHES_24)
PLATFORM_CPPFLAGS += -DPLATFORM_FORTIS_DP7000
DRIVER_PLATFORM   += FORTIS_DP7000=fortis_dp7000
endif
#
PLATFORM_CPPFLAGS := CPPFLAGS="$(PLATFORM_CPPFLAGS)"
#

#V ?= 0
#export V

