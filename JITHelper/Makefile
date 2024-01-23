TARGET := iphone:clang:16.5:14.0
ARCHS = arm64

TARGET_CODESIGN = ../Exploits/fastPathSign/fastPathSign

include $(THEOS)/makefiles/common.mk

TOOL_NAME = trollstorejithelper

trollstorejithelper_FILES = $(wildcard *.m)
trollstorejithelper_CODESIGN_FLAGS = --entitlements entitlements.plist
trollstorejithelper_INSTALL_PATH = /usr/local/bin
trollstorejithelper_PRIVATE_FRAMEWORKS = RunningBoardServices

include $(THEOS_MAKE_PATH)/tool.mk
