TARGET := iphone:clang:16.5:14.0
INSTALL_TARGET_PROCESSES = TrollStoreLite
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TrollStoreLite

TrollStoreLite_FILES = $(wildcard ../TrollStore/*.m) $(wildcard ../Shared/*.m)
TrollStoreLite_FRAMEWORKS = UIKit CoreGraphics CoreServices CoreTelephony
TrollStoreLite_PRIVATE_FRAMEWORKS = Preferences MobileIcons MobileContainerManager
TrollStoreLite_LIBRARIES = archive
TrollStoreLite_CFLAGS = -fobjc-arc -I../Shared -I$(shell brew --prefix)/opt/libarchive/include -DTROLLSTORE_LITE
TrollStoreLite_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
