#import <Foundation/Foundation.h>
#import "MemoryPatcher.h"

NS_ASSUME_NONNULL_BEGIN

/// 单个功能项
@interface Feature : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, copy) NSArray<PatchEntry*> *patches; // 该功能的全部补丁
@end

/// 功能管理器：维护功能列表、应用/还原补丁、持久化开关状态。
@interface FeatureManager : NSObject
@property (nonatomic, copy) NSArray<Feature*> *features;
+ (instancetype)shared;
/// 载入功能定义（Features.buildDefaultFeatures）并叠加持久化状态。
- (void)reload;
/// 设置某功能开关：启用则写入补丁，关闭则还原原始字节，并持久化。
- (BOOL)setEnabled:(BOOL)enabled forFeature:(Feature*)feature;
/// 把当前所有功能开关状态写入持久化文件。
- (void)saveState;
/// 持久化文件路径（Library/Application Support/<bundle>/features.plist）。
- (NSString*)stateFilePath;
@end

NS_ASSUME_NONNULL_END
