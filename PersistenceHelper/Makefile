TARGET := iphone:clang:14.5:14.0
INSTALL_TARGET_PROCESSES = TrollStorePersistenceHelper

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TrollStorePersistenceHelper

TrollStorePersistenceHelper_FILES = $(wildcard *.m) ../Helper/Shared.m ../Store/TSUtil.m ../Store/TSListControllerShared.m
TrollStorePersistenceHelper_FRAMEWORKS = UIKit CoreGraphics CoreServices
TrollStorePersistenceHelper_PRIVATE_FRAMEWORKS = Preferences
TrollStorePersistenceHelper_CFLAGS = -fobjc-arc
TrollStorePersistenceHelper_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

internal-stage::
	ldid -S -M -K../_compile/cert.p12 $(THEOS_STAGING_DIR)/Applications/TrollStorePersistenceHelper.app/TrollStorePersistenceHelper