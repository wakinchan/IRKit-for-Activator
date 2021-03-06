export TARGET = iphone::7.0
export ARCHS = armv7 arm64
export GO_EASY_ON_ME = 1

include /opt/theos/makefiles/common.mk

TWEAK_NAME = IRKitforActivator
IRKitforActivator_FILES = Tweak.xm UIImage+IRKit.m NSString+Hashes.m
IRKitforActivator_FRAMEWORKS = UIKit QuartzCore
IRKitforActivator_LIBRARIES = activator objcipc
IRKitforActivator_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS = IRKitSubstrate_Activator

include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"
