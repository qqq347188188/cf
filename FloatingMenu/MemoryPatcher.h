#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>

NS_ASSUME_NONNULL_BEGIN

/// 单条补丁：针对某个模块（默认 "cf"）文件内的 link-time 虚拟地址，记录原始字节与作弊字节。
@interface PatchEntry : NSObject
@property (nonatomic, copy) NSString *module;   // 模块名（主二进制通常为 "cf"）
@property (nonatomic, assign) uintptr_t vmaddr;  // 文件中的 link-time 虚拟地址（如 0x10171a48c）
@property (nonatomic, copy) NSData *original;   // 原始字节
@property (nonatomic, copy) NSData *patched;    // 注入的字节
+ (instancetype)entryWithModule:(NSString*)module
                         vmaddr:(uintptr_t)vmaddr
                       original:(NSData*)original
                        patched:(NSData*)patched;
@end

/// 运行时内存补丁器：负责地址换算与代码段写入。
@interface MemoryPatcher : NSObject

/// 把模块（如 "cf"）文件中的 link-time vmaddr 换算为当前进程的实际地址（含 ASLR slide）。
+ (uintptr_t)actualAddressForVMAddr:(uintptr_t)vmaddr inModule:(NSString*)module;

/// 在指定实际地址写入数据（自动修改页面权限为 RWX 再恢复为 RX）。
+ (BOOL)writeBytes:(const void*)bytes length:(size_t)len atActualAddress:(uintptr_t)addr;

/// 应用一条补丁（写入 patched 字节）。
+ (BOOL)applyPatch:(PatchEntry*)patch;
/// 还原一条补丁（写回 original 字节）。
+ (BOOL)restorePatch:(PatchEntry*)patch;

@end

NS_ASSUME_NONNULL_END
