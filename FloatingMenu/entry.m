#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import "FloatingMenu.h"
#import "FeatureManager.h"

// dylib 入口：被 LC_LOAD_DYLIB 加载时执行。
// 此时 UIApplication 尚未完全就绪，故延迟到主线程 runloop 起来后再初始化 UI。
__attribute__((constructor)) static void floatingmenu_entry(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[FeatureManager shared] reload];       // 载入功能 + 持久化开关 + 应用已开启项
        [[FloatingMenuManager shared] show];    // 显示可拖动悬浮窗与功能面板
    });
}
