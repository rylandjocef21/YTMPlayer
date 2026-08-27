TARGET = iphone:clang:9.3:9.0
ARCHS = armv7

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = YTMPlayer
YTMPlayer_FILES = main.m YTMAppDelegate.m YTMViewController.m
YTMPlayer_FRAMEWORKS = UIKit AVFoundation CoreGraphics MediaPlayer

include $(THEOS_MAKE_PATH)/application.mk
