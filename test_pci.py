import ctypes
import os
import random
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

os.system("setpci  -s 02:00.0 COMMAND=0x02")
os.system("setpci  -s 02:00.0 98.b=0x16")  # 98 = 0x70(base) + 0x28(DevCtl2 offset), 0x16 means disable completion timeout


# 使用内存（示例）

va_src = addr
va_dst = addr + 1024*1024

src_buffer = (ctypes.c_char * size).from_address(va_src)
dst_buffer = (ctypes.c_char * size).from_address(va_dst)


def test_throughput():
    for offset in range(0, 1024*1024, 4):
        src_buffer[offset:offset + 4] = (offset//4).to_bytes(4, byteorder="little")
        dst_buffer[offset:offset + 4] = (0).to_bytes(4, byteorder="little")
    
    
    src_buffer[:5] = b'Hello'  # 写入数据
    print(src_buffer[:10])       # 读取数据
    dst_buffer[:5] = b'world'  # 写入数据
    print(dst_buffer[:10])
    
    pa_src = va_to_pa(addr) # + 2
    
    pa_dst = va_to_pa(addr + 1024*1024) # + 3
    
    req_size = 4096
    stride_size = 0
    stride_cnt = 32

    double_channel_offset = 1024*512 # double channel test enabled
    # double_channel_offset = 0 # double channel test disabled
    
    with open('/sys/bus/pci/devices/0000:02:00.0/resource1', 'r+b') as f:
        # 将文件映射到内存
        with mmap.mmap(f.fileno(), 0) as mm:
    
            struct.pack_into('<I', mm, 0x4, pa_src & 0xFFFFFFFF)
            struct.pack_into('<I', mm, 0x8, pa_src >> 32)
            struct.pack_into('<I', mm, 0xc, pa_dst & 0xFFFFFFFF)
            struct.pack_into('<I', mm, 0x10, pa_dst >> 32)
            struct.pack_into('<I', mm, 0x14, req_size)
            struct.pack_into('<I', mm, 0x1c, stride_size)
            struct.pack_into('<I', mm, 0x20, stride_cnt)
            struct.pack_into('<I', mm, 0x24, 0b000_000)

            struct.pack_into('<I', mm, 0x28, double_channel_offset)  

            # struct.pack_into('<I', mm, 0x2C, 0b00)  # read write test
            # struct.pack_into('<I', mm, 0x2C, 0b01)  # read only test
            struct.pack_into('<I', mm, 0x2C, 0b10)  # write only test
    
            print(hex(struct.unpack_from('<I', mm, offset=0x4)[0]))
            print(hex(struct.unpack_from('<I', mm, offset=0x8)[0]))
            print(hex(struct.unpack_from('<I', mm, offset=0xc)[0]))
            print(hex(struct.unpack_from('<I', mm, offset=0x10)[0]))
            print(hex(struct.unpack_from('<I', mm, offset=0x14)[0]))
            
    
    
            last_time = time.time()
            iter_last_a = 1
            iter_now_a = 2
            iter_last_b = 1
            iter_now_b = 2
            for _ in range(1):
                struct.pack_into('<I', mm, 0x18, 0x1ffffff)
                iter_last_a = struct.unpack_from('<I', mm, offset=0x18)[0]
                iter_last_b = struct.unpack_from('<I', mm, offset=0x30)[0]
                while iter_last_a != 0 or iter_last_b != 0:
                
                    time.sleep(1)
                    iter_now_a = struct.unpack_from('<I', mm, offset=0x18)[0]
                    iter_now_b = struct.unpack_from('<I', mm, offset=0x30)[0]

                    now_time = time.time()
                
                    time_delta = now_time - last_time
                    iter_delta_a = iter_last_a - iter_now_a
                    iter_delta_b = iter_last_b - iter_now_b
                    iter_delta = iter_delta_a + iter_delta_b
                    speed = (iter_delta * req_size * 8) / time_delta / 1024 / 1024 / 1024
    
                    print(f"speed = {speed} Gbps, iter_left_a={iter_last_a}, iter_left_b={iter_last_b}")
                    iter_last_a = iter_now_a
                    iter_last_b = iter_now_b
                    last_time = now_time
    
    time.sleep(0.1)
    
    print(dst_buffer[:10])



def test_correct():
    for offset in range(0, 1024*1024, 1):
        src_buffer[offset] = offset % 256
        dst_buffer[offset] = 0
    
    
    
    pa_src = va_to_pa(addr)
    
    pa_dst = va_to_pa(addr + 1024*1024)
    
    
    with open('/sys/bus/pci/devices/0000:02:00.0/resource1', 'r+b') as f:
        # 将文件映射到内存
        with mmap.mmap(f.fileno(), 0) as mm:
    
    
    
            last_time = time.time()
            iter_last = 1
            iter_now = 2
            for iter_idx in range(10000000):
                print(f"iter={iter_idx}")

                req_size =  random.randint(1, 4096)
                stride_size = req_size
                stride_cnt =  random.randint(1, 8)
                
                src_offset =  random.randint(0, 1024*128)
                dst_offset =  src_offset # random.randint(0, 1024*512)

                req_cnt = stride_cnt

                struct.pack_into('<I', mm, 0x4, (pa_src + src_offset) & 0xFFFFFFFF)
                struct.pack_into('<I', mm, 0x8, pa_src >> 32)
                struct.pack_into('<I', mm, 0xc, (pa_dst + dst_offset) & 0xFFFFFFFF)
                struct.pack_into('<I', mm, 0x10, pa_dst >> 32)
                struct.pack_into('<I', mm, 0x14, req_size)
                struct.pack_into('<I', mm, 0x1c, stride_size)
                struct.pack_into('<I', mm, 0x20, stride_cnt)
                # struct.pack_into('<I', mm, 0x24, 0b000)
    
                
                # print(hex(struct.unpack_from('<I', mm, offset=0x4)[0]))
                # print(hex(struct.unpack_from('<I', mm, offset=0x8)[0]))
                # print(hex(struct.unpack_from('<I', mm, offset=0xc)[0]))
                # print(hex(struct.unpack_from('<I', mm, offset=0x10)[0]))
                # print(hex(struct.unpack_from('<I', mm, offset=0x14)[0]))

                print(f"src_offset = {hex(src_offset)}, dst_offset = {hex(dst_offset)}, req_size={hex(req_size)}, stride_cnt={hex(stride_cnt)}, src_addr={hex(pa_src + src_offset)}, dst_addr={hex(pa_dst + dst_offset)}")


                struct.pack_into('<I', mm, 0x18, req_cnt)
                while iter_last != 0:
                    time.sleep(0.00001)
                    iter_last = struct.unpack_from('<I', mm, offset=0x18)[0]
                #input()
                #time.sleep(1)
                total_bytes_copy = req_size * req_cnt
    

                for offset in range(0, dst_offset, 1):
                    if dst_buffer[offset] != b'\x00':
                        print(f"should not be modified, dst_buffer[{hex(offset)})={hex(int.from_bytes(dst_buffer[offset], byteorder='little'))}")
                        raise SystemExit

                
                for (s_offset, d_offset) in zip(range(src_offset, src_offset + total_bytes_copy, 1), range(dst_offset, dst_offset + total_bytes_copy, 1)):
                    if dst_buffer[d_offset] != src_buffer[s_offset]:
                        time.sleep(0.001) 
                        if dst_buffer[d_offset] != src_buffer[s_offset]:
                            print(f"not match, dst_buffer[{hex(d_offset)}]={hex(int.from_bytes(dst_buffer[d_offset], byteorder='little'))}, src_buffer[{hex(s_offset)}]={hex(int.from_bytes(src_buffer[s_offset],byteorder='little'))}")
                            raise SystemExit
                    dst_buffer[d_offset] = 0

                for offset in range(dst_offset + total_bytes_copy, 1024 * 256, 1):
                    if dst_buffer[offset] != b'\x00':
                        print(f"should not be modified, dst_buffer[{hex(offset)})={hex(int.from_bytes(dst_buffer[offset], byteorder='little'))}")
                        raise SystemExit



def pcie_p2p():

    for offset in range(0, 1024*1024, 1):
        src_buffer[offset] = 0
        dst_buffer[offset] = 0

    # pa_src = va_to_pa(addr)
    # pa_dst = 0xfb800000
    # src_offset =  0x00
    # dst_offset =  0x1048
    

    pa_src = 0xfb800000
    pa_dst = va_to_pa(addr + 1024*1024)
    src_offset =  0x1048
    dst_offset =  0x00

    with open('/sys/bus/pci/devices/0000:02:00.0/resource1', 'r+b') as f:
        # 将文件映射到内存
        with mmap.mmap(f.fileno(), 0) as mm:

            req_size =  4
            stride_size = 1
            stride_cnt =  1
            
            req_cnt = stride_cnt

            struct.pack_into('<I', mm, 0x4, (pa_src + src_offset) & 0xFFFFFFFF)
            struct.pack_into('<I', mm, 0x8, pa_src >> 32)
            struct.pack_into('<I', mm, 0xc, (pa_dst + dst_offset) & 0xFFFFFFFF)
            struct.pack_into('<I', mm, 0x10, pa_dst >> 32)
            struct.pack_into('<I', mm, 0x14, req_size)
            struct.pack_into('<I', mm, 0x1c, stride_size)
            struct.pack_into('<I', mm, 0x20, stride_cnt)

            print(f"src_offset = {hex(src_offset)}, dst_offset = {hex(dst_offset)}, req_size={hex(req_size)}, stride_cnt={hex(stride_cnt)}, src_addr={hex(pa_src + src_offset)}, dst_addr={hex(pa_dst + dst_offset)}")

            struct.pack_into('<I', mm, 0x18, req_cnt)

            time.sleep(0.01)

            total_bytes_copy = req_size * req_cnt

            print(f'read result =  {hex(int.from_bytes(dst_buffer[0:4],byteorder="little"))}')
    

# test_correct()
test_throughput()
# pcie_p2p()


# 释放内存
libc.munmap(addr, size)

