#import <Foundation/Foundation.h>
#import "FeatureManager.h"

NS_ASSUME_NONNULL_BEGIN

/// 默认功能清单构造器：把 7 处 il2cpp 补丁封装成 2 个可开关功能。
@interface Features : NSObject
+ (NSArray<Feature*>*)buildDefaultFeatures;
@end

NS_ASSUME_NONNULL_END
