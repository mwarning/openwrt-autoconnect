#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk

PKG_NAME:=autoconnect
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define Package/autoconnect
	SECTION:=net
	CATEGORY:=Network
	TITLE:=SSID Autoconnect
	MAINTAINER:=Moritz Warning <moritzwarning@web.de>
endef

define Package/autoconnect/description
	Autoconnect to one of the available SSIDs configured in /etc/config/wireless
endef


define Package/autoconnect/install
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) files/autoconnect.sh $(1)/bin
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) files/autoconnect.postinst $(1)/etc/uci-defaults/90_autoconnect
endef

$(eval $(call BuildPackage,autoconnect))
