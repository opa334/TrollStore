export EMBEDDED_ROOT_HELPER ?= 0
export LEGACY_CT_BUG ?= 0

TARGET := iphone:clang:16.5:14.0
INSTALL_TARGET_PROCESSES = TrollStorePersistenceHelper

ifdef CUSTOM_ARCHS
ARCHS = $(CUSTOM_ARCHS)
else
ARCHS = arm64
endif

ifneq ($(LEGACY_CT_BUG),1)
TARGET_CODESIGN = ../Exploits/fastPathSign/fastPathSign
endif

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TrollStorePersistenceHelper

TrollStorePersistenceHelper_FILES = $(wildcard *.m) $(wildcard ../Shared/*.m)
TrollStorePersistenceHelper_FRAMEWORKS = UIKit CoreGraphics CoreServices CoreTelephony
TrollStorePersistenceHelper_PRIVATE_FRAMEWORKS = Preferences MobileContainerManager
TrollStorePersistenceHelper_CFLAGS = -fobjc-arc -I../Shared -I$(shell brew --prefix)/opt/libarchive/include

ifeq ($(LEGACY_CT_BUG),1)
TrollStorePersistenceHelper_CODESIGN_FLAGS = -Sentitlements.plist -K../legacy.p12
TrollStorePersistenceHelper_CFLAGS += -DLEGACY_CT_BUG=1
else
TrollStorePersistenceHelper_CODESIGN_FLAGS = --entitlements entitlements.plist
endif

ifeq ($(EMBEDDED_ROOT_HELPER),1)
TrollStorePersistenceHelper_CFLAGS += -DEMBEDDED_ROOT_HELPER=1
TrollStorePersistenceHelper_FILES += $(wildcard ../RootHelper/*.m)
TrollStorePersistenceHelper_LIBRARIES += archive
TrollStorePersistenceHelper_PRIVATE_FRAMEWORKS += SpringBoardServices BackBoardServices FrontBoardServices
endif

include $(THEOS_MAKE_PATH)/application.mk