TARGET = iphone:clang:9.3:9.0
ARCHS = armv7

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = YTMPlayer
YTMPlayer_FILES = main.m YTMAppDelegate.m YTMViewController.m
YTMPlayer_FRAMEWORKS = UIKit AVFoundation CoreGraphics MediaPlayer

# Disable module errors and bypass missing driver stubs in modern Xcode linkers
YTMPlayer_CFLAGS = -fno-modules -Wno-deprecated-module-dot-map -Wno-error
YTMPlayer_LDFLAGS = -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/application.mk
