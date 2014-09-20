export TARGET = iphone::7.0
export ARCHS = armv7 arm64
export GO_EASY_ON_ME = 1

include /opt/theos/makefiles/common.mk

TWEAK_NAME = IRKitSubstrate_Activator
IRKitSubstrate_Activator_FILES = IRKitSubstrate_Activator.xm ../NSString+Hashes.m ../UIImage+IRKit.m
IRKitSubstrate_Activator_FRAMEWORKS = UIKit QuartzCore
IRKitSubstrate_Activator_LIBRARIES = objcipc
IRKitSubstrate_Activator_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
