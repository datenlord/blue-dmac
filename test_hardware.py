import ctypes
import os

import mmap
import struct
import time


def va_to_pa(va):
    page_size = os.sysconf(os.sysconf_names['SC_PAGESIZE'])
    # page_size = 2*1024*1024
    page_offset = va % page_size
    pagemap_entry_offset = (va // page_size) * 8  # 每个条目8字节

    try:
        with open('/proc/self/pagemap', 'rb') as f:
            f.seek(pagemap_entry_offset)
            entry_bytes = f.read(8)
            if len(entry_bytes) != 8:
                raise ValueError("Invalid pagemap entry")

            entry = int.from_bytes(entry_bytes, byteorder='little')
            if not (entry & (1 << 63)):  # 检查页面是否在内存中
                raise ValueError("Page not present in physical memory")

            pfn = entry & 0x7FFFFFFFFFFFFF  # 提取PFN
            print(f"pfn={hex(pfn)}")
            return (pfn * page_size) + page_offset

    except IOError as e:
        raise RuntimeError(f"Failed to access pagemap: {e}")


# 定义 mmap 相关常量
PROT_READ = 1
PROT_WRITE = 2
MAP_SHARED = 0x01
MAP_HUGETLB = 0x40000  # 巨页内存标志
MAP_LOCKED = 0x02000
MAP_ANONYMOUS = 0x20

# 定义 mmap 函数
libc = ctypes.CDLL("libc.so.6")
cmmap = libc.mmap
cmmap.restype = ctypes.c_void_p
cmmap.argtypes = (
    ctypes.c_void_p, ctypes.c_size_t,
    ctypes.c_int, ctypes.c_int,
    ctypes.c_int, ctypes.c_long
)

# 申请 2MB 巨页内存
size = 2 * 1024 * 1024  # 2MB
addr = cmmap(
    0, size,
    PROT_READ | PROT_WRITE,
    MAP_SHARED | MAP_ANONYMOUS | MAP_HUGETLB | MAP_LOCKED,
    -1, 0
)

if addr == -1:
    raise OSError("Failed to allocate huge page memory")


# 使用内存（示例）

va_src = addr
va_dst = addr + 1024*1024

src_buffer = (ctypes.c_char * size).from_address(va_src)
dst_buffer = (ctypes.c_char * size).from_address(va_dst)

for offset in range(0, 1024*1024, 4):
    src_buffer[offset:offset + 4] = (offset//4).to_bytes(4, byteorder="little")
    dst_buffer[offset:offset + 4] = (0).to_bytes(4, byteorder="little")


src_buffer[:5] = b'Hello'  # 写入数据
print(src_buffer[:10])       # 读取数据
dst_buffer[:5] = b'world'  # 写入数据
print(dst_buffer[:10])

pa_src = va_to_pa(addr)

pa_dst = va_to_pa(addr + 1024*1024)

with open('/sys/bus/pci/devices/0000:02:00.0/resource1', 'r+b') as f:
    # 将文件映射到内存
    with mmap.mmap(f.fileno(), 0) as mm:

        struct.pack_into('<I', mm, 0x4, pa_src & 0xFFFFFFFF)
        struct.pack_into('<I', mm, 0x8, pa_src >> 32)
        struct.pack_into('<I', mm, 0xc, pa_dst & 0xFFFFFFFF)
        struct.pack_into('<I', mm, 0x10, pa_dst >> 32)
        struct.pack_into('<I', mm, 0x14, 128)

        print(struct.unpack_from('<I', mm, offset=0x4)[0])
        print(struct.unpack_from('<I', mm, offset=0x8)[0])
        print(struct.unpack_from('<I', mm, offset=0xc)[0])
        print(struct.unpack_from('<I', mm, offset=0x10)[0])
        print(struct.unpack_from('<I', mm, offset=0x14)[0])

        struct.pack_into('<I', mm, 0x18, 1)


time.sleep(0.1)

print(dst_buffer[:10])

# 释放内存
libc.munmap(addr, size)
