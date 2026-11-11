#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 悬浮窗管理器：在游戏进程内创建一个置顶、可拖动的悬浮按钮，
/// 点击后弹出功能面板（列表 + 开关）。运行在与游戏相同的进程内。
@interface FloatingMenuManager : NSObject
+ (instancetype)shared;
- (void)show;
- (void)hide;
@end

NS_ASSUME_NONNULL_END
