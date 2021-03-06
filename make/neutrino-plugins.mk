#
# Makefile to build NEUTRINO-PLUGINS
#

#
# links
#
LINKS_VER = 2.7
LINKS_PATCH  = links-$(LINKS_VER).patch
ifeq ($(BOXTYPE), $(filter $(BOXTYPE), spark spark7162))
LINKS_PATCH += links-$(LINKS_VER)-spark-input.patch
endif

$(ARCHIVE)/links-$(LINKS_VER).tar.bz2:
	$(WGET) http://links.twibright.com/download/links-$(LINKS_VER).tar.bz2

$(D)/links: $(D)/bootstrap $(D)/libpng $(D)/openssl $(ARCHIVE)/links-$(LINKS_VER).tar.bz2
	$(START_BUILD)
	$(REMOVE)/links-$(LINKS_VER)
	$(UNTAR)/links-$(LINKS_VER).tar.bz2
	$(SET) -e; cd $(BUILD_TMP)/links-$(LINKS_VER); \
		$(call apply_patches,$(LINKS_PATCH)); \
		$(CONFIGURE) \
			--prefix= \
			--mandir=/.remove \
			--without-svgalib \
			--without-x \
			--without-libtiff \
			--enable-graphics \
			--enable-javascript \
			--with-ssl; \
		$(MAKE); \
		$(MAKE) install DESTDIR=$(TARGET_DIR)
	$(SILENT)mkdir -p $(TARGET_DIR)/var/tuxbox/plugins $(TARGET_DIR)/var/tuxbox/config/links
	$(SILENT)mv $(TARGET_DIR)/bin/links $(TARGET_DIR)/var/tuxbox/plugins/links.so
	echo "name=Links Web Browser"	 > $(TARGET_DIR)/var/tuxbox/plugins/links.cfg
	echo "desc=Web Browser"		>> $(TARGET_DIR)/var/tuxbox/plugins/links.cfg
	echo "type=2"			>> $(TARGET_DIR)/var/tuxbox/plugins/links.cfg
	echo "needfb=1"			>> $(TARGET_DIR)/var/tuxbox/plugins/links.cfg
	echo "needrc=1"			>> $(TARGET_DIR)/var/tuxbox/plugins/links.cfg
	echo "needoffsets=1"		>> $(TARGET_DIR)/var/tuxbox/plugins/links.cfg
	echo "bookmarkcount=0"		 > $(TARGET_DIR)/var/tuxbox/config/bookmarks
	$(SILENT)touch $(TARGET_DIR)/var/tuxbox/config/links/links.his
	$(SILENT)cp -a $(SKEL_ROOT)/var/tuxbox/config/links/bookmarks.html $(SKEL_ROOT)/var/tuxbox/config/links/tables.tar.gz $(TARGET_DIR)/var/tuxbox/config/links
	$(REMOVE)/links-$(LINKS_VER)
	$(TOUCH)

#
# neutrino-mp-plugins
#
NEUTRINO_PLUGINS  = $(D)/neutrino-mp-plugin
NEUTRINO_PLUGINS += $(D)/neutrino-mp-plugin-scripts-lua
NEUTRINO_PLUGINS += $(D)/neutrino-mp-plugin-mediathek
NEUTRINO_PLUGINS += $(D)/neutrino-mp-plugin-xupnpd

NP_OBJDIR = $(BUILD_TMP)/neutrino-mp-plugins

ifeq ($(BOXARCH), sh4)
EXTRA_CPPFLAGS_MP_PLUGINS = -DMARTII
endif

$(D)/neutrino-mp-plugin.do_prepare:
	$(SILENT)rm -rf $(SOURCE_DIR)/neutrino-mp-plugins
	$(SILENT)rm -rf $(SOURCE_DIR)/neutrino-mp-plugins.org
	$(SET) -e; if [ -d $(ARCHIVE)/neutrino-mp-plugins.git ]; \
		then cd $(ARCHIVE)/neutrino-mp-plugins.git; git pull -q; \
		else cd $(ARCHIVE); git clone -q https://github.com/Duckbox-Developers/neutrino-mp-plugins.git neutrino-mp-plugins.git; \
		fi
	$(SILENT)cp -ra $(ARCHIVE)/neutrino-mp-plugins.git $(SOURCE_DIR)/neutrino-mp-plugins
ifeq ($(BOXARCH), arm)
	$(SILENT)sed -i -e 's#shellexec fx2#shellexec stb-startup#g' $(SOURCE_DIR)/neutrino-mp-plugins/Makefile.am
endif
	cp -ra $(SOURCE_DIR)/neutrino-mp-plugins $(SOURCE_DIR)/neutrino-mp-plugins.org
	@touch $@

$(D)/neutrino-mp-plugin.config.status: $(D)/bootstrap
	$(SILENT)rm -rf $(NP_OBJDIR)
	$(SILENT)test -d $(NP_OBJDIR) || mkdir -p $(NP_OBJDIR)
	$(SILENT)cd $(NP_OBJDIR); \
		$(SOURCE_DIR)/neutrino-mp-plugins/autogen.sh && automake --add-missing; \
		$(BUILDENV) \
		$(SOURCE_DIR)/neutrino-mp-plugins/configure $(SILENT_OPT) \
			--host=$(TARGET) \
			--build=$(BUILD) \
			--prefix= \
			--enable-silent-rules \
			--with-target=cdk \
			--oldinclude=$(TARGET_DIR)/include \
			--enable-maintainer-mode \
			--with-boxtype=$(BOXTYPE) \
			--with-plugindir=/var/tuxbox/plugins \
			--with-libdir=/usr/lib \
			--with-datadir=/usr/share/tuxbox \
			--with-fontdir=/usr/share/fonts \
			PKG_CONFIG=$(PKG_CONFIG) \
			PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) \
			CPPFLAGS="$(N_CPPFLAGS) $(EXTRA_CPPFLAGS_MP_PLUGINS) -DNEW_LIBCURL" \
			LDFLAGS="$(TARGET_LDFLAGS) -L$(NP_OBJDIR)/fx2/lib/.libs"
	@touch $@

$(D)/neutrino-mp-plugin.do_compile: $(D)/neutrino-mp-plugin.config.status
	$(MAKE) -C $(NP_OBJDIR) DESTDIR=$(TARGET_DIR)
	@touch $@

$(D)/neutrino-mp-plugin: $(D)/neutrino-mp-plugin.do_prepare $(D)/neutrino-mp-plugin.do_compile
	$(START_BUILD)
	$(MAKE) -C $(NP_OBJDIR) install DESTDIR=$(TARGET_DIR)
	$(TOUCH)

neutrino-mp-plugin-clean:
	$(SILENT)rm -f $(D)/neutrino-mp-plugins
	$(SILENT)rm -f $(D)/neutrino-mp-plugin
	$(SILENT)rm -f $(D)/neutrino-mp-plugin.config.status
	$(SILENT)cd $(NP_OBJDIR); \
		$(MAKE) -C $(NP_OBJDIR) clean

neutrino-mp-plugin-distclean:
	$(SILENT)rm -rf $(NP_OBJDIR)
	$(SILENT)rm -f $(D)/neutrino-mp-plugin*

#
# xupnpd
#
XUPNPD_PATCH = xupnpd.patch

$(D)/xupnpd \
$(D)/neutrino-mp-plugin-xupnpd: $(D)/bootstrap $(D)/lua $(D)/openssl $(D)/neutrino-mp-plugin-scripts-lua
	$(START_BUILD)
	$(REMOVE)/xupnpd
	$(SET) -e; if [ -d $(ARCHIVE)/xupnpd.git ]; \
		then cd $(ARCHIVE)/xupnpd.git; git pull; \
		else cd $(ARCHIVE); git clone git://github.com/clark15b/xupnpd.git xupnpd.git; \
		fi
	$(SILENT)cp -ra $(ARCHIVE)/xupnpd.git $(BUILD_TMP)/xupnpd
	$(SET) -e; cd $(BUILD_TMP)/xupnpd; \
		$(call apply_patches,$(XUPNPD_PATCH))
	$(SET) -e; cd $(BUILD_TMP)/xupnpd/src; \
		$(BUILDENV) \
		$(MAKE) -j1 embedded TARGET=$(TARGET) PKG_CONFIG=$(PKG_CONFIG) LUAFLAGS="$(TARGET_LDFLAGS) -I$(TARGET_INCLUDE_DIR)"; \
		$(MAKE) install DESTDIR=$(TARGET_DIR)
	$(SILENT)install -m 755 $(SKEL_ROOT)/etc/init.d/xupnpd $(TARGET_DIR)/etc/init.d/
	$(SILENT)mkdir -p $(TARGET_DIR)/usr/share/xupnpd/config
	$(SILENT)rm $(TARGET_DIR)/usr/share/xupnpd/plugins/staff/xupnpd_18plus.lua
	$(SILENT)install -m 644 $(ARCHIVE)/plugin-scripts-lua.git/xupnpd/xupnpd_18plus.lua ${TARGET_DIR}/usr/share/xupnpd/plugins/
	$(SILENT)install -m 644 $(ARCHIVE)/plugin-scripts-lua.git/xupnpd/xupnpd_cczwei.lua ${TARGET_DIR}/usr/share/xupnpd/plugins/
	: install -m 644 $(ARCHIVE)/plugin-scripts-lua.git/xupnpd/xupnpd_coolstream.lua ${TARGET_DIR}/usr/share/xupnpd/plugins/
	$(SILENT)install -m 644 $(ARCHIVE)/plugin-scripts-lua.git/xupnpd/xupnpd_youtube.lua ${TARGET_DIR}/usr/share/xupnpd/plugins/
	$(REMOVE)/xupnpd
	$(TOUCH)

#
# neutrino-plugin-scripts-lua
#
$(D)/neutrino-mp-plugin-scripts-lua: $(D)/bootstrap
	$(START_BUILD)
	$(REMOVE)/neutrino-mp-plugin-scripts-lua
	$(SET) -e; if [ -d $(ARCHIVE)/plugin-scripts-lua.git ]; \
		then cd $(ARCHIVE)/plugin-scripts-lua.git; git pull; \
		else cd $(ARCHIVE); git clone -q https://github.com/tuxbox-neutrino/plugin-scripts-lua.git plugin-scripts-lua.git; \
		fi
	$(SILENT)cp -ra $(ARCHIVE)/plugin-scripts-lua.git/plugins $(BUILD_TMP)/neutrino-mp-plugin-scripts-lua
	$(SET) -e; cd $(BUILD_TMP)/neutrino-mp-plugin-scripts-lua; \
		install -d $(TARGET_DIR)/var/tuxbox/plugins
		cp -R $(BUILD_TMP)/neutrino-mp-plugin-scripts-lua/ard_mediathek/* $(TARGET_DIR)/var/tuxbox/plugins/
		cp -R $(BUILD_TMP)/neutrino-mp-plugin-scripts-lua/favorites2bin/* $(TARGET_DIR)/var/tuxbox/plugins/
		cp -R $(BUILD_TMP)/neutrino-mp-plugin-scripts-lua/mtv/* $(TARGET_DIR)/var/tuxbox/plugins/
		cp -R $(BUILD_TMP)/neutrino-mp-plugin-scripts-lua/netzkino/* $(TARGET_DIR)/var/tuxbox/plugins/
	$(REMOVE)/neutrino-mp-plugin-scripts-lua
	$(TOUCH)

#
# neutrino-mediathek
#
NEUTRINO_MEDIATHEK_PATCH = neutrino-mediathek.patch

$(D)/neutrino-mp-plugin-mediathek:
	$(START_BUILD)
	$(REMOVE)/plugins-mediathek
	$(SET) -e; if [ -d $(ARCHIVE)/plugins-mediathek.git ]; \
		then cd $(ARCHIVE)/plugins-mediathek.git; git pull; \
		else cd $(ARCHIVE); git clone https://github.com/neutrino-mediathek/mediathek.git plugins-mediathek.git; \
		fi
	$(SILENT)cp -ra $(ARCHIVE)/plugins-mediathek.git $(BUILD_TMP)/plugins-mediathek
	$(SILENT)install -d $(TARGET_DIR)/var/tuxbox/plugins
	$(SET) -e; cd $(BUILD_TMP)/plugins-mediathek; \
		$(call apply_patches,$(NEUTRINO_MEDIATHEK_PATCH))
	$(SET) -e; cd $(BUILD_TMP)/plugins-mediathek; \
		cp -a plugins/* $(TARGET_DIR)/var/tuxbox/plugins/; \
		cp -a share $(TARGET_DIR)/usr
	$(REMOVE)/plugins-mediathek
	$(TOUCH)

#
# neutrino-hd2 plugins
#
NEUTRINO_HD2_PLUGINS_PATCHES =

$(D)/neutrino-hd2-plugins.do_prepare:
	$(SILENT)rm -rf $(SOURCE_DIR)/neutrino-hd2-plugins
	$(SILENT)ln -s $(SOURCE_DIR)/neutrino-hd2.git/plugins $(SOURCE_DIR)/neutrino-hd2-plugins
	$(SET) -e; cd $(SOURCE_DIR)/neutrino-hd2-plugins; \
		$(call apply_patches,$(NEUTRINO_HD2_PLUGINS_PATCHES))
	@touch $@

$(D)/neutrino-hd2-plugins.config.status: $(D)/bootstrap neutrino-hd2
	$(SILENT)cd $(SOURCE_DIR)/neutrino-hd2-plugins; \
		./autogen.sh; \
		$(BUILDENV) \
		./configure $(SILENT_OPT) \
			--host=$(TARGET) \
			--build=$(BUILD) \
			--prefix= \
			--with-target=cdk \
			--with-boxtype=$(BOXTYPE) \
			--with-plugindir=/var/tuxbox/plugins \
			--with-datadir=/usr/share/tuxbox \
			--with-fontdir=/usr/share/fonts \
			--enable-silent-rules \
			PKG_CONFIG=$(PKG_CONFIG) \
			PKG_CONFIG_PATH=$(PKG_CONFIG_PATH) \
			CPPFLAGS="$(CPPFLAGS) -I$(driverdir) -I$(KERNEL_DIR)/include -I$(TARGET_DIR)/include" \
			LDFLAGS="$(TARGET_LDFLAGS)"
	@touch $@

$(D)/neutrino-hd2-plugins.do_compile: $(D)/neutrino-hd2-plugins.config.status
	$(SILENT)cd $(SOURCE_DIR)/neutrino-hd2-plugins
	$(MAKE) top_srcdir=$(SOURCE_DIR)/neutrino-hd2
	@touch $@

$(D)/neutrino-hd2-plugins.build: neutrino-hd2-plugins.do_prepare neutrino-hd2-plugins.do_compile
	$(START_BUILD)
	$(MAKE) -C $(SOURCE_DIR)/neutrino-hd2-plugins install DESTDIR=$(TARGET_DIR) top_srcdir=$(SOURCE_DIR)/neutrino-hd2
	$(TOUCH)

neutrino-hd2-plugins-clean:
	$(SILENT)cd $(SOURCE_DIR)/neutrino-hd2-plugins
	$(MAKE) clean
	$(SILENT)rm -f $(D)/neutrino-hd2-plugins.build
	$(SILENT)rm -f $(D)/neutrino-hd2-plugins.config.status

neutrino-hd2-plugins-distclean:
	rm -f $(D)/neutrino-hd2-plugins.build
	rm -f $(D)/neutrino-hd2-plugins.config.status
	rm -f $(D)/neutrino-hd2-plugins.do_prepare
	rm -f $(D)/neutrino-hd2-plugins.do_compile
