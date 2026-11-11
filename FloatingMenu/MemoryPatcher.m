#import "MemoryPatcher.h"

// iOS 页面大小（arm64 为 16KB）
#define PAGE_MASK_16K (~(0x3FFFULL))

@implementation PatchEntry
+ (instancetype)entryWithModule:(NSString*)module
                         vmaddr:(uintptr_t)vmaddr
                       original:(NSData*)original
                        patched:(NSData*)patched {
    PatchEntry *e = [[PatchEntry alloc] init];
    e.module = module ?: @"cf";
    e.vmaddr = vmaddr;
    e.original = original;
    e.patched = patched;
    return e;
}
@end

@implementation MemoryPatcher

/// 解析 Mach-O 头部，取出 __TEXT 段在文件里的 link-time vmaddr（用于地址换算）。
+ (uintptr_t)__textLinkVMAddrFromHeader:(const struct mach_header_64*)hdr {
    uintptr_t cmdPtr = (uintptr_t)hdr + sizeof(struct mach_header_64);
    for (uint32_t i = 0; i < hdr->ncmds; i++) {
        struct load_command *lc = (struct load_command*)cmdPtr;
        if (lc->cmd == LC_SEGMENT_64) {
            struct segment_command_64 *seg = (struct segment_command_64*)lc;
            if (strncmp(seg->segname, "__TEXT", 6) == 0) {
                return (uintptr_t)seg->vmaddr;
            }
        }
        cmdPtr += lc->cmdsize;
    }
    return 0x100000000; // 兜底：iOS 64 位常用基址
}

+ (uintptr_t)actualAddressForVMAddr:(uintptr_t)vmaddr inModule:(NSString*)module {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        NSString *nsname = [[NSString stringWithUTF8String:name] lastPathComponent];
        if (![nsname isEqualToString:module]) continue;
        const struct mach_header_64 *hdr = (const struct mach_header_64*)_dyld_get_image_header(i);
        if (!hdr) continue;
        uintptr_t linkTextVM = [self __textLinkVMAddrFromHeader:hdr];
        // 运行时实际地址 = 实际加载基址 + (link-time vmaddr - link-time __TEXT vmaddr)
        return (uintptr_t)hdr + (vmaddr - linkTextVM);
    }
    return 0;
}

+ (BOOL)writeBytes:(const void*)bytes length:(size_t)len atActualAddress:(uintptr_t)addr {
    // 按 16KB 页对齐
    vm_address_t page = (vm_address_t)(addr & PAGE_MASK_16K);
    kern_return_t kr = vm_protect(mach_task_self(), page, 0x4000, FALSE,
                                  VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
    if (kr != KERN_SUCCESS) {
        // 代码段受硬件保护（APRR/KTRR，无越狱设备常见）时内核会拒绝，
        // 此时无法运行时改写 __TEXT，需要越狱环境或改用固化补丁方案。
        NSLog(@"[MemoryPatcher] vm_protect failed kr=0x%x addr=%p", kr, (void*)addr);
        return NO;
    }
    memcpy((void*)addr, bytes, len);
    // 还原为可执行只读
    vm_protect(mach_task_self(), page, 0x4000, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    return YES;
}

+ (BOOL)applyPatch:(PatchEntry*)patch {
    uintptr_t addr = [self actualAddressForVMAddr:patch.vmaddr inModule:patch.module];
    if (!addr) return NO;
    return [self writeBytes:patch.patched.bytes length:patch.patched.length atActualAddress:addr];
}

+ (BOOL)restorePatch:(PatchEntry*)patch {
    uintptr_t addr = [self actualAddressForVMAddr:patch.vmaddr inModule:patch.module];
    if (!addr) return NO;
    return [self writeBytes:patch.original.bytes length:patch.original.length atActualAddress:addr];
}

@end
