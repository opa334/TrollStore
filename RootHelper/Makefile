TARGET := iphone:clang:14.5:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TOOL_NAME = trollstorehelper

trollstorehelper_FILES = $(wildcard *.m) $(wildcard ../Shared/*.m)
trollstorehelper_CFLAGS = -fobjc-arc -I../Shared
trollstorehelper_CODESIGN_FLAGS = -Sentitlements.plist -K../cert.p12
trollstorehelper_INSTALL_PATH = /usr/local/bin
trollstorehelper_LIBRARIES = archive
trollstorehelper_PRIVATE_FRAMEWORKS = SpringBoardServices BackBoardServices MobileContainerManager

include $(THEOS_MAKE_PATH)/tool.mk
