#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把悬浮窗 dylib 整合进「砸壳后的明文 app」，输出可直接用 TrollStore 安装/重签的 IPA。
（TrollStore 安装时会对 app 内所有可执行做 ad-hoc 重签，故此处不另行 codesign。）

用法:
  python package_ipa.py <明文 cf.app 目录> <FloatingMenu.dylib> <输出.ipa>

示例:
  python package_ipa.py "D:\\decrypted\\cf.app" FloatingMenu.dylib cf_floatingmenu.ipa
"""
import sys, os, struct, shutil, zipfile, tempfile

MH_MAGIC_64 = 0xFEEDFACF
LC_SEGMENT_64 = 0x19
LC_CODE_SIGNATURE = 0x1D
LC_LOAD_DYLIB = 0xC

def align(v, a):
    return (v + a - 1) & ~(a - 1)

def inject(data: bytes, load_path: str) -> bytes:
    magic = struct.unpack_from('<I', data, 0)[0]
    if magic != MH_MAGIC_64:
        raise Exception("不是 MH_MAGIC_64")
    (_, _, _, ncmds, sizeofcmds, _, _) = struct.unpack_from('<7I', data, 4)
    off = 32
    cssig = None
    first_data = None
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from('<II', data, off)
        if cmd == LC_CODE_SIGNATURE:
            cssig = off
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
    name_b = load_path.encode() + b'\x00'
    name_b += b'\x00' * ((-len(name_b)) % 8)
    cmdsize = align(24 + len(name_b), 8)
    lc = struct.pack('<IIIIII', LC_LOAD_DYLIB, cmdsize, 24, 2, 0x10000, 0x10000) + name_b
    if len(lc) > avail:
        raise Exception("load command 区空闲空间不足")
    insert_at = cssig if cssig is not None else lc_end
    new = bytearray(data[:insert_at] + lc + data[insert_at:])
    struct.pack_into('<I', new, 16, ncmds + 1)
    struct.pack_into('<I', new, 20, sizeofcmds + cmdsize)
    return bytes(new)

def main():
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(1)
    app_dir, dylib, out_ipa = sys.argv[1], sys.argv[2], sys.argv[3]
    if not os.path.isdir(app_dir):
        raise SystemExit("app 目录不存在: " + app_dir)
    cf_src = os.path.join(app_dir, 'cf')
    if not os.path.isfile(cf_src):
        raise SystemExit("找不到主二进制 cf: " + cf_src)
    if not os.path.isfile(dylib):
        raise SystemExit("找不到 dylib: " + dylib)

    tmp = tempfile.mkdtemp()
    try:
        payload = os.path.join(tmp, 'Payload')
        dest = os.path.join(payload, os.path.basename(app_dir.rstrip('/\\')))
        shutil.copytree(app_dir, dest)

        cf_dest = os.path.join(dest, 'cf')
        d = open(cf_dest, 'rb').read()
        if b'FloatingMenu.dylib' not in d:
            d = inject(d, '@executable_path/Frameworks/FloatingMenu.dylib')
            open(cf_dest, 'wb').write(d)
            print("已注入 LC_LOAD_DYLIB -> FloatingMenu.dylib")

        fw = os.path.join(dest, 'Frameworks')
        os.makedirs(fw, exist_ok=True)
        shutil.copy(dylib, os.path.join(fw, 'FloatingMenu.dylib'))
        print("已放置 dylib -> Frameworks/FloatingMenu.dylib")

        with zipfile.ZipFile(out_ipa, 'w', zipfile.ZIP_DEFLATED) as z:
            for root, _, files in os.walk(payload):
                for f in files:
                    fp = os.path.join(root, f)
                    arc = os.path.relpath(fp, tmp)
                    z.write(fp, arc)
        print("已生成 IPA ->", out_ipa)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

if __name__ == '__main__':
    main()
