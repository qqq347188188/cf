#import "FeatureManager.h"
#import "Features.h"
#import "MemoryPatcher.h"

@implementation Feature

- (NSString*)description {
    return [NSString stringWithFormat:@"<%@:%@ enabled=%d>", self.identifier, self.displayName, self.enabled];
}

@end

@implementation FeatureManager

+ (instancetype)shared {
    static FeatureManager *m = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [[FeatureManager alloc] init]; });
    return m;
}

- (NSString*)stateFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *dir = [paths.firstObject stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier] ?: @"FloatingMenu"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir stringByAppendingPathComponent:@"features.plist"];
}

- (void)reload {
    self.features = [Features buildDefaultFeatures];
    NSDictionary *saved = [NSDictionary dictionaryWithContentsOfFile:[self stateFilePath]];
    if (saved) {
        for (Feature *f in self.features) {
            NSNumber *v = saved[f.identifier];
            if (v) {
                f.enabled = v.boolValue;
                // 重新应用已开启的功能；若写入失败则标记关闭，避免 UI 与真实状态不符
                if (f.enabled) {
                    for (PatchEntry *p in f.patches) {
                        if (![MemoryPatcher applyPatch:p]) { f.enabled = NO; break; }
                    }
                }
            }
        }
    }
}

- (BOOL)setEnabled:(BOOL)enabled forFeature:(Feature*)feature {
    BOOL ok = YES;
    for (PatchEntry *p in feature.patches) {
        BOOL r = enabled ? [MemoryPatcher applyPatch:p] : [MemoryPatcher restorePatch:p];
        if (!r) { ok = NO; break; }   // 任一补丁写入失败即整体失败，避免半成品
    }
    if (ok) {
        feature.enabled = enabled;
        [self saveState];
    }
    return ok;
}

- (void)saveState {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (Feature *f in self.features) d[f.identifier] = @(f.enabled);
    [d writeToFile:[self stateFilePath] atomically:YES];
}

@end
