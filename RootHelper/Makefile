TARGET := iphone:clang:16.5:14.0
ARCHS = arm64

ifdef TROLLSTORE_LITE
HELPER_NAME = trollstorehelper_lite
else
HELPER_NAME = trollstorehelper
TARGET_CODESIGN = ../Exploits/fastPathSign/fastPathSign
endif

include $(THEOS)/makefiles/common.mk

TOOL_NAME = $(HELPER_NAME)

$(HELPER_NAME)_FILES = $(wildcard *.m) $(wildcard ../Shared/*.m) $(wildcard ../ChOma/src/*.c)

ifndef TROLLSTORE_LITE
$(HELPER_NAME)_FILES += ../Exploits/fastPathSign/src/coretrust_bug.c ../Exploits/fastPathSign/src/codesign.m
$(HELPER_NAME)_CODESIGN_FLAGS = --entitlements entitlements.plist
$(HELPER_NAME)_LDFLAGS = -L../ChOma/external/ios -lcrypto
else
$(HELPER_NAME)_CODESIGN_FLAGS = -Sentitlements.plist
endif
 
$(HELPER_NAME)_CFLAGS = -fobjc-arc -I../Shared $(shell pkg-config --cflags libcrypto) -I../ChOma/src -I../Exploits/fastPathSign/src -I$(shell brew --prefix)/opt/libarchive/include

$(HELPER_NAME)_INSTALL_PATH = /usr/local/bin
$(HELPER_NAME)_LIBRARIES = archive
$(HELPER_NAME)_FRAMEWORKS = CoreTelephony
$(HELPER_NAME)_PRIVATE_FRAMEWORKS = SpringBoardServices BackBoardServices MobileContainerManager FrontBoardServices RunningBoardServices

ifdef TROLLSTORE_LITE
$(HELPER_NAME)_CFLAGS += -DTROLLSTORE_LITE -DDISABLE_SIGNING=1
endif

include $(THEOS_MAKE_PATH)/tool.mk
