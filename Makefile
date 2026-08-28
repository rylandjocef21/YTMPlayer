TARGET = iphone:clang:latest:9.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = YTMPlayer
YTMPlayer_FILES = main.m YTMAppDelegate.m YTMViewController.m \
                  YTMNetworkClient.m YTMTrackParser.m YTMPlayerManager.m
YTMPlayer_FRAMEWORKS = UIKit AVFoundation CoreGraphics MediaPlayer
YTMPlayer_CODESIGN_FLAGS = -S

# Enable ARC for Objective-C files to use __weak safely and avoid MRC crashes
ADDITIONAL_OBJCFLAGS += -fobjc-arc

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "chmod 755 /Applications/YTMPlayer.app/YTMPlayer && su mobile -c uicache"
