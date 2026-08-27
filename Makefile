TARGET = iphone:clang:11.2:9.0
ARCHS = armv7

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = YTMPlayer
YTMPlayer_FILES = main.m YTMAppDelegate.m YTMViewController.m
YTMPlayer_FRAMEWORKS = UIKit AVFoundation CoreGraphics MediaPlayer

YTMPlayer_CFLAGS = -fno-modules -Wno-deprecated-module-dot-map -Wno-error
YTMPlayer_LDFLAGS = -Wl,-fatal_warnings_off -Wl,-missing_main

include $(THEOS_MAKE_PATH)/application.mk
