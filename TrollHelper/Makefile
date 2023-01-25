export EMBEDDED_ROOT_HELPER ?= 0

TARGET := iphone:clang:14.5:14.0
INSTALL_TARGET_PROCESSES = TrollStorePersistenceHelper

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TrollStorePersistenceHelper

TrollStorePersistenceHelper_FILES = $(wildcard *.m) $(wildcard ../Shared/*.m)
TrollStorePersistenceHelper_FRAMEWORKS = UIKit CoreGraphics CoreServices
TrollStorePersistenceHelper_PRIVATE_FRAMEWORKS = Preferences MobileContainerManager
TrollStorePersistenceHelper_CFLAGS = -fobjc-arc -I../Shared
TrollStorePersistenceHelper_CODESIGN_FLAGS = -Sentitlements.plist -K../cert.p12

ifeq ($(EMBEDDED_ROOT_HELPER),1)
TrollStorePersistenceHelper_CFLAGS += -DEMBEDDED_ROOT_HELPER=1
TrollStorePersistenceHelper_FILES += $(wildcard ../RootHelper/*.m)
TrollStorePersistenceHelper_LIBRARIES += archive
TrollStorePersistenceHelper_PRIVATE_FRAMEWORKS += SpringBoardServices BackBoardServices
endif

include $(THEOS_MAKE_PATH)/application.mk