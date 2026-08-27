TARGET = iphone:clang:latest:9.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = YTMPlayer
# Find your existing source files line in Makefile and append LTYouTubeClient.m
YTM_FILES = main.m YTMAppDelegate.m YTMViewController.m LTYouTubeClient.m
YTMPlayer_FRAMEWORKS = UIKit AVFoundation CoreGraphics MediaPlayer

# This line is critical for iOS 10 icon display
YTMPlayer_RESOURCE_FILES = Info.plist Icon-60@2x.png

include $(THEOS_MAKE_PATH)/application.mk
