TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = YTMPlayer

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = YTMPlayer

YTMPlayer_FILES = main.m YTMAppDelegate.m YTMViewController.m
YTMPlayer_FRAMEWORKS = UIKit CoreGraphics AVAudioFoundation MediaPlayer

include $(THEOS)/makefiles/application.mk
