TARGET := iphone:clang:14.5:14.0
INSTALL_TARGET_PROCESSES = TrollStore

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TrollStore

TrollStore_FILES = $(wildcard *.m) $(wildcard ../Shared/*.m)
TrollStore_FRAMEWORKS = UIKit CoreGraphics CoreServices
TrollStore_PRIVATE_FRAMEWORKS = Preferences MobileIcons MobileContainerManager
TrollStore_LIBRARIES = archive
TrollStore_CFLAGS = -fobjc-arc -I../Shared
TrollStore_CODESIGN_FLAGS = -Sentitlements.plist -K../cert.p12

include $(THEOS_MAKE_PATH)/application.mk
