TARGET := iphone:clang:14.5:14.0
INSTALL_TARGET_PROCESSES = TrollInstaller2
ARCHS = arm64e

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TrollInstaller2

TrollInstaller2_FILES = main.m $(wildcard *.m) $(wildcard ../../Helper/*.m) ../../Store/TSListControllerShared.m ../../Store/TSUtil.m
TrollInstaller2_FRAMEWORKS = UIKit CoreGraphics
TrollInstaller2_PRIVATE_FRAMEWORKS = Preferences
TrollInstaller2_LIBRARIES = archive
TrollInstaller2_CFLAGS = -fobjc-arc -DINSTALLER_EMBEDDED=1
TrollInstaller2_PRIVATE_FRAMEWORKS = SpringBoardServices BackBoardServices
TrollInstaller2_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
