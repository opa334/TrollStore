TARGET := iphone:clang:14.5:14.0
INSTALL_TARGET_PROCESSES = TrollStore

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TrollStore

TrollStore_FILES = $(wildcard *.m) ../Helper/Shared.m
TrollStore_FRAMEWORKS = UIKit CoreGraphics CoreServices
TrollStore_PRIVATE_FRAMEWORKS = Preferences
TrollStore_CFLAGS = -fobjc-arc
TrollStore_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
