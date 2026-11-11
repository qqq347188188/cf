#import <UIKit/UIKit.h>
#import "FloatingMenu.h"
#import "FeatureManager.h"

// theos 注入入口：在 UIApplication 启动后，于主线程初始化悬浮窗与功能状态。
%hook UIApplication

- (void)_run {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                  dispatch_get_main_queue(), ^{
        [[FeatureManager shared] reload];      // 载入功能 + 叠加持久化开关 + 应用已开启项
        [[FloatingMenuManager shared] show];   // 显示可拖动悬浮按钮与面板
    });
}

%end

/*
 * 若改用 TrollStore / 无 theos 的 dylib 注入方式，把上面的 %hook 换成下面这个
 * constructor 入口即可（编译成 .dylib 后注入 cf 的 LC_LOAD_DYLIB）：
 *
 *   #import <mach-o/dyld.h>
 *   __attribute__((constructor)) static void floatingmenu_entry() {
 *       dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0*NSEC_PER_SEC)),
 *                      dispatch_get_main_queue(), ^{
 *           [[FeatureManager shared] reload];
 *           [[FloatingMenuManager shared] show];
 *       });
 *   }
 */
