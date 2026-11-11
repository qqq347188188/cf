#import "Features.h"
#import "MemoryPatcher.h"

// 小工具：十六进制字符串 -> NSData
static NSData *hexData(NSString *s) {
    NSMutableData *d = [NSMutableData data];
    for (NSUInteger i = 0; i + 1 < s.length; i += 2) {
        unsigned int v = 0;
        [[NSScanner scannerWithString:[s substringWithRange:NSMakeRange(i, 2)]] scanHexInt:&v];
        uint8_t b = (uint8_t)v;
        [d appendBytes:&b length:1];
    }
    return d;
}

// 构造一条补丁；module 默认 "cf"（游戏主二进制名）
#define P(vm, orig, pat) \
    [PatchEntry entryWithModule:@"cf" vmaddr:(vm) original:hexData(@orig) patched:hexData(@pat)]

@implementation Features

+ (NSArray<Feature*>*)buildDefaultFeatures {
    // —— 补丁 1：set_PlayerInfo 整个函数变 ret（禁用描边限制逻辑）——
    PatchEntry *p1 = P(0x10171a48c, @"5fd6ff0301", @"5fd6c0035f");
    // —— 补丁 2：某 .ctor 返回值 1 -> 0（开关翻转）——
    PatchEntry *p2 = P(0x104d314cc, @"5fd6200080", @"5fd6000080");
    // —— 补丁 5：Reset 整个函数变 ret ——
    PatchEntry *p5 = P(0x104ff1bd8, @"dd17ff4301d1e923", @"dd17c0035fd6e923");

    // —— 补丁 3：参数构造处强制 w1=1、s2 清 0（范围伤害参数）——
    PatchEntry *p3 = P(0x104e0f838, @"13aae10315aae041", @"13aa21008052e003");
    // —— 补丁 4：把对象字段 0x210 写入 100（范围/半径）——
    PatchEntry *p4 = P(0x104ec88c4, @"241e090821", @"241e290821");
    // —— 补丁 6：强制某标志 = 1 ——
    PatchEntry *p6 = P(0x1051b38e8, @"aa2001", @"aa2000");
    // —— 补丁 7：配置系数 getter 改值 ——
    PatchEntry *p7 = P(0x107faa720, @"940078", @"940010");

    // 功能一：透视描边（禁用限制逻辑，使描边常开）
    Feature *wallhack = [[Feature alloc] init];
    wallhack.identifier = @"wallhack";
    wallhack.displayName = @"透视描边";
    wallhack.patches = @[p1, p2, p5];

    // 功能二：范围伤害（吸附模式伤害判定放大为范围）
    Feature *aoe = [[Feature alloc] init];
    aoe.identifier = @"aoe_damage";
    aoe.displayName = @"范围伤害";
    aoe.patches = @[p3, p4, p6, p7];

    return @[wallhack, aoe];
}

@end
