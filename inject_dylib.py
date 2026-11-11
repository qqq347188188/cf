#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把 FloatingMenu.dylib 注入到明文 cf 的 LC_LOAD_DYLIB，输出可直接由
TrollStore 安装/重签的 cf。

用法:
  python inject_dylib.py --check <输入cf>                 # 仅检查空闲空间
  python inject_dylib.py <输入cf> <dylib在app内的加载路径> <输出cf>

示例:
  python inject_dylib.py Desktop\\cf @executable_path/Frameworks/FloatingMenu.dylib injected_cf.bin
"""
import sys, struct

MH_MAGIC_64 = 0xFEEDFACF
LC_SEGMENT_64 = 0x19
LC_CODE_SIGNATURE = 0x1D
LC_LOAD_DYLIB = 0xC

def align(v, a):
    return (v + a - 1) & ~(a - 1)

def inject(data: bytes, load_path: str):
    if len(data) < 32:
        raise Exception("文件过小")
    magic = struct.unpack_from('<I', data, 0)[0]
    if magic != MH_MAGIC_64:
        raise Exception("不是 MH_MAGIC_64 (0x%X)" % magic)
    (_, _, _, ncmds, sizeofcmds, _, _) = struct.unpack_from('<7I', data, 4)

    off = 32
    cssig_off = None
    first_data = None
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from('<II', data, off)
        if cmd == LC_CODE_SIGNATURE:
            cssig_off = off
        elif cmd == LC_SEGMENT_64:
            nsects = struct.unpack_from('<I', data, off + 64)[0]
            soff = off + 72
            for _s in range(nsects):
                sec_off = struct.unpack_from('<I', data, soff + 0x30)[0]
                if sec_off and (first_data is None or sec_off < first_data):
                    first_data = sec_off
                soff += 80
        off += cmdsize

    lc_end = 32 + sizeofcmds
    data_start = first_data if first_data else 0x3000
    avail = data_start - lc_end

    name_b = load_path.encode('utf-8') + b'\x00'
    name_b += b'\x00' * ((-len(name_b)) % 8)
    cmdsize = align(24 + len(name_b), 8)
    # LC_LOAD_DYLIB: cmd, cmdsize, (name_off, timestamp, cur_ver, comp_ver), name
    lc = struct.pack('<IIIIII', LC_LOAD_DYLIB, cmdsize, 24, 2, 0x10000, 0x10000) + name_b

    if len(lc) > avail:
        raise Exception("load command 区空闲空间不足: 需要 %d, 仅有 %d" % (len(lc), avail))

    insert_at = cssig_off if cssig_off is not None else lc_end
    new = bytearray(data[:insert_at] + lc + data[insert_at:])
    struct.pack_into('<I', new, 16, ncmds + 1)
    struct.pack_into('<I', new, 20, sizeofcmds + cmdsize)
    return bytes(new)

def check(data: bytes):
    magic = struct.unpack_from('<I', data, 0)[0]
    if magic != MH_MAGIC_64:
        return "不是 MH_MAGIC_64"
    (_, _, _, ncmds, sizeofcmds, _, _) = struct.unpack_from('<7I', data, 4)
    off = 32
    cssig = None
    first_data = None
    has_lc_dylib = False
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from('<II', data, off)
        if cmd == LC_CODE_SIGNATURE: cssig = off
        if cmd == LC_LOAD_DYLIB: has_lc_dylib = True
        if cmd == LC_SEGMENT_64:
            nsects = struct.unpack_from('<I', data, off + 64)[0]
            soff = off + 72
            for _s in range(nsects):
                sec_off = struct.unpack_from('<I', data, soff + 0x30)[0]
                if sec_off and (first_data is None or sec_off < first_data):
                    first_data = sec_off
                soff += 80
        off += cmdsize
    lc_end = 32 + sizeofcmds
    data_start = first_data if first_data else 0x3000
    avail = data_start - lc_end
    return ("ncmds=%d sizeofcmds=%d 空闲空间=%d 字节 LC_SIGN=%s 已有LC_LOAD_DYLIB=%s"
            % (ncmds, sizeofcmds, avail, cssig is not None, has_lc_dylib))

if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--check':
        d = open(sys.argv[2], 'rb').read()
        print(check(d))
    elif len(sys.argv) == 4:
        inp, lp, outp = sys.argv[1], sys.argv[2], sys.argv[3]
        d = open(inp, 'rb').read()
        if lp.encode() in d:
            print("已包含该 dylib 引用，跳过")
            open(outp, 'wb').write(d)
        else:
            r = inject(d, lp)
            open(outp, 'wb').write(r)
            print("已注入 %s -> %s (输出 %d 字节)" % (lp, outp, len(r)))
    else:
        print(__doc__)
        sys.exit(1)
