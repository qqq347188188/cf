#import "FloatingMenu.h"
#import "FeatureManager.h"
#import "MemoryPatcher.h"

/// 穿透式窗口：只在命中自身子视图（按钮/面板）时拦截事件，空白区域让触摸穿透到下层游戏窗口。
@interface PassthroughWindow : UIWindow
@end
@implementation PassthroughWindow
- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self) ? nil : hit;
}
@end

@interface FloatingMenuManager () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIButton *floatButton;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) BOOL panelVisible;
@end

@implementation FloatingMenuManager

+ (instancetype)shared {
    static FloatingMenuManager *m = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [[FloatingMenuManager alloc] init]; });
    return m;
}

- (void)show {
    if (self.overlayWindow) return; // 已显示

    // 1) 取当前激活的 windowScene（iOS 13+），保证悬浮窗有正确的 UI 坐标环境
    UIWindowScene *scene = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] &&
                ((UIWindowScene*)s).activationState == UISceneActivationStateForegroundActive) {
                scene = (UIWindowScene*)s; break;
            }
        }
    }

    // 2) 创建穿透式 overlay 窗口（空白不拦截触摸，游戏可正常操作）
    self.overlayWindow = [[PassthroughWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    if (@available(iOS 13.0, *)) self.overlayWindow.windowScene = scene;
    self.overlayWindow.windowLevel = UIWindowLevelStatusBar + 100;
    self.overlayWindow.backgroundColor = [UIColor clearColor];
    self.overlayWindow.rootViewController = [UIViewController new];
    self.overlayWindow.hidden = NO;

    // 3) 可拖动悬浮按钮
    self.floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.floatButton setTitle:@"菜单" forState:UIControlStateNormal];
    self.floatButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    self.floatButton.backgroundColor = [UIColor colorWithRed:0.20 green:0.60 blue:1.0 alpha:0.85];
    self.floatButton.layer.cornerRadius = 28;
    self.floatButton.frame = CGRectMake(24, 120, 56, 56);
    [self.floatButton addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragButton:)];
    [self.floatButton addGestureRecognizer:pan];
    [self.overlayWindow addSubview:self.floatButton];

    // 4) 功能面板（默认隐藏）
    [self buildPanel];
}

- (void)hide {
    self.overlayWindow.hidden = YES;
    self.overlayWindow = nil;
    self.floatButton = nil;
    self.panel = nil;
    self.tableView = nil;
}

#pragma mark - 拖动

- (void)dragButton:(UIPanGestureRecognizer*)g {
    CGPoint p = [g locationInView:self.overlayWindow];
    CGFloat hw = self.floatButton.bounds.size.width / 2;
    CGFloat hh = self.floatButton.bounds.size.height / 2;
    p.x = MAX(hw, MIN(self.overlayWindow.bounds.size.width - hw, p.x));
    p.y = MAX(hh, MIN(self.overlayWindow.bounds.size.height - hh, p.y));
    self.floatButton.center = p;
}

#pragma mark - 面板

- (void)buildPanel {
    CGFloat w = 260, h = 360;
    self.panel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    self.panel.center = self.overlayWindow.center;
    self.panel.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.96];
    self.panel.layer.cornerRadius = 14;
    self.panel.layer.borderColor = [UIColor whiteColor].CGColor;
    self.panel.layer.borderWidth = 0.5;
    self.panel.hidden = YES;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, w, 40)];
    title.text = @"功能开关";
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont boldSystemFontOfSize:16];
    [self.panel addSubview:title];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeCustom];
    [close setTitle:@"×" forState:UIControlStateNormal];
    close.frame = CGRectMake(w - 40, 0, 40, 40);
    [close addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:close];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(8, 44, w - 16, h - 52) style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.2];
    [self.panel addSubview:self.tableView];

    [self.overlayWindow addSubview:self.panel];
}

- (void)togglePanel {
    self.panelVisible = !self.panelVisible;
    [UIView animateWithDuration:0.2 animations:^{
        self.panel.alpha = self.panelVisible ? 1.0 : 0.0;
        self.panel.hidden = !self.panelVisible;
    }];
    if (self.panelVisible) [self.tableView reloadData];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    return [FeatureManager shared].features.count;
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        // UISwitch 仅在创建 cell 时建立并绑定一次，避免复用导致重复 addTarget
        UISwitch *sw = [[UISwitch alloc] init];
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    }
    Feature *f = [FeatureManager shared].features[indexPath.row];
    cell.textLabel.text = f.displayName;
    UISwitch *sw = (UISwitch*)cell.accessoryView;
    sw.on = f.enabled;
    sw.tag = indexPath.row;
    return cell;
}

- (void)switchChanged:(UISwitch*)sw {
    Feature *f = [FeatureManager shared].features[sw.tag];
    BOOL ok = [[FeatureManager shared] setEnabled:sw.on forFeature:f];
    if (!ok) {
        // 写入失败（如代码段受硬件保护无法改写）：保持内存真实状态，不翻转 UI 误导用户
        sw.on = f.enabled;
    }
}

@end
