TARGET := iphone:clang:14.5:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TOOL_NAME = trollstorehelper

trollstorehelper_FILES = $(wildcard *.m)
trollstorehelper_CFLAGS = -fobjc-arc
trollstorehelper_CODESIGN_FLAGS = -Sentitlements.plist
trollstorehelper_INSTALL_PATH = /usr/local/bin
trollstorehelper_LIBRARIES = archive
trollstorehelper_PRIVATE_FRAMEWORKS = SpringBoardServices BackBoardServices

include $(THEOS_MAKE_PATH)/tool.mk
