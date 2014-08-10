export TARGET = :clang
ARCHS = armv7 armv7s arm64

include /opt/theos/makefiles/common.mk

TWEAK_NAME = IRKitSubstrate_Activator
IRKitSubstrate_Activator_FILES = IRKitSubstrate_Activator.xm ../NSString+Hashes.m
IRKitSubstrate_Activator_FRAMEWORKS = UIKit QuartzCore
IRKitSubstrate_Activator_LIBRARIES = objcipc

include $(THEOS_MAKE_PATH)/tweak.mk