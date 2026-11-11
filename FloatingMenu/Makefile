TARGET = iphone:clang:latest:14.0
ARCHS = arm64

TWEAK_NAME = FloatingMenu
FloatingMenu_FILES = Tweak.xm FloatingMenu.m FeatureManager.m Features.m MemoryPatcher.m
FloatingMenu_CFLAGS = -fobjc-arc -I.
FloatingMenu_FRAMEWORKS = UIKit Foundation

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

# 安装后重启游戏主二进制（cf）使注入生效
after-install::
	@echo "restarting cf..."
	install.exec "killall -9 cf" || true
