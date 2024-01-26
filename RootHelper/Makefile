TARGET := iphone:clang:16.5:14.0
ARCHS = arm64

TARGET_CODESIGN = ../Exploits/fastPathSign/fastPathSign

include $(THEOS)/makefiles/common.mk

TOOL_NAME = trollstorehelper

trollstorehelper_FILES = $(wildcard *.m) $(wildcard ../Shared/*.m) $(wildcard ../ChOma/src/*.c) ../Exploits/fastPathSign/src/coretrust_bug.c ../Exploits/fastPathSign/src/codesign.m
trollstorehelper_CFLAGS = -fobjc-arc -I../Shared $(shell pkg-config --cflags libcrypto) -I../ChOma/src -I../Exploits/fastPathSign/src
trollstorehelper_LDFLAGS = -L../ChOma/external/ios -lcrypto
trollstorehelper_CODESIGN_FLAGS = --entitlements entitlements.plist
trollstorehelper_INSTALL_PATH = /usr/local/bin
trollstorehelper_LIBRARIES = archive
trollstorehelper_FRAMEWORKS = CoreTelephony
trollstorehelper_PRIVATE_FRAMEWORKS = SpringBoardServices BackBoardServices MobileContainerManager FrontBoardServices RunningBoardServices

include $(THEOS_MAKE_PATH)/tool.mk
