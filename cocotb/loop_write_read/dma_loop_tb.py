import os
import sys
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))) # fmt: off 

import random

import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

import cocotb_test.simulator
from bdmatb import BdmaLoopTb


tests_dir = os.path.dirname(__file__)
rtl_dir = tests_dir


async def loop_write_read_once(pcie_tb, mem):
    # addr, length = pcie_tb.gen_random_req(0)
    addr = 1
    length = 2378
    addr = mem.get_absolute_address(addr)
    char = bytes(random.choice('abcdefghijklmnopqrstuvwxyz'), encoding="UTF-8")
    data = char * length
    mem[addr:addr+length] = data
    await pcie_tb.run_single_read_once(0, addr, length)
    new_addr = addr + 8192
    await pcie_tb.run_single_write_once(0, new_addr, length)
    await Timer(200+4*length, units='ns')
    assert mem[new_addr:new_addr+length] == data



async def throughput_test(dut, dev, mem):
   
    print(f"before=================={mem[10:15]}")

    desc_transfer_szie = 1024
    stride_size = 1024
    strise_cnt = 32


    dev_bar1 = dev.bar_window[1]
    await dev_bar1.write(0x04, (0).to_bytes(4, byteorder='little', signed=False))
    await dev_bar1.write(0x08, (0).to_bytes(4, byteorder='little', signed=False))

    await dev_bar1.write(0x0C, (1024*1024).to_bytes(4, byteorder='little', signed=False))
    await dev_bar1.write(0x10, (0).to_bytes(4, byteorder='little', signed=False))

    await dev_bar1.write(0x14, (desc_transfer_szie).to_bytes(4, byteorder='little', signed=False))
    await dev_bar1.write(0x1C, (stride_size).to_bytes(4, byteorder='little', signed=False))
    await dev_bar1.write(0x20, (strise_cnt).to_bytes(4, byteorder='little', signed=False))

    await dev_bar1.write(0x28, (1024*512).to_bytes(4, byteorder='little', signed=False))

    await dev_bar1.write(0x2c, (0x00).to_bytes(4, byteorder='little', signed=False))  # read write
    # await dev_bar1.write(0x2c, (0x01).to_bytes(4, byteorder='little', signed=False))  # read only
    # await dev_bar1.write(0x2c, (0x02).to_bytes(4, byteorder='little', signed=False))  # write only

    await dev_bar1.write(0x18, (0xFFF).to_bytes(4, byteorder='little', signed=False))

    calc_time_ns = 5000
    old_val = int.from_bytes(await dev_bar1.read(0x18, 4), 'little') 
    old_time = cocotb.utils.get_sim_time("ns")
    while True:
        await Timer(calc_time_ns, "ns")
        new_val = int.from_bytes(await dev_bar1.read(0x18, 4), 'little')
        new_time = cocotb.utils.get_sim_time("ns")
        value_delta = old_val - new_val
        time_delta = new_time-old_time
        speed = desc_transfer_szie * 8 * (value_delta) / (time_delta)
        
        print(f"old_value={old_val}, new_value={new_val}, value_delta={value_delta}, time_delta={time_delta}, speed={speed} Gbps")

        old_val = new_val
        old_time = new_time

        if new_val == 0:
            break

    print(f"after=================={mem[10:15]}")



async def correct_test(dut, dev, mem):

    dev_bar1 = dev.bar_window[1]

    for iter_idx in range(1000):

        req_size = random.randint(1, 4096)
        stride_size = req_size
        stride_cnt =  random.randint(1, 8)

        src_offset =  random.randint(0, 1024*128)
        dst_offset =  src_offset # random.randint(0, 1024*512)

        req_cnt = stride_cnt
        double_channel_test_offset = 0

        await dev_bar1.write(0x04, (src_offset).to_bytes(4, byteorder='little', signed=False))
        await dev_bar1.write(0x08, (0).to_bytes(4, byteorder='little', signed=False))

        await dev_bar1.write(0x0C, (1024*1024 + dst_offset).to_bytes(4, byteorder='little', signed=False))
        await dev_bar1.write(0x10, (0).to_bytes(4, byteorder='little', signed=False))

        await dev_bar1.write(0x14, (req_size).to_bytes(4, byteorder='little', signed=False))
        await dev_bar1.write(0x1C, (stride_size).to_bytes(4, byteorder='little', signed=False))
        await dev_bar1.write(0x20, (stride_cnt).to_bytes(4, byteorder='little', signed=False))
        await dev_bar1.write(0x28, (double_channel_test_offset).to_bytes(4, byteorder='little', signed=False))

        print(f"src_offset = {hex(src_offset)}, dst_offset = {hex(dst_offset)}, req_size={hex(req_size)}, stride_cnt={hex(stride_cnt)}")

        await dev_bar1.write(0x18, (req_cnt).to_bytes(4, byteorder='little', signed=False))

        while True:
            new_val = int.from_bytes(await dev_bar1.read(0x18, 4), 'little')
            if new_val == 0:
                break
            await Timer(100, "ns")
        
        await Timer(5000, "ns")

        total_bytes_copy = req_size * req_cnt

        src_buffer = mem[0:]
        dst_buffer = mem[1024*1024:]

        for offset in range(0, dst_offset, 1):
            if dst_buffer[offset] != 0:
                print(f"A should not be modified, dst_buffer[{hex(offset)}]={hex(dst_buffer[offset])}")
                raise SystemExit
        for (s_offset, d_offset) in zip(range(src_offset, src_offset + total_bytes_copy, 1), range(dst_offset, dst_offset + total_bytes_copy, 1)):
            if dst_buffer[d_offset] != src_buffer[s_offset]:
                print(f"A not match, dst_buffer[{hex(d_offset)}]={hex(dst_buffer[d_offset])}, src_buffer[{hex(s_offset)}]={hex(src_buffer[s_offset])}")
                raise SystemExit
            mem[1024*1024 + d_offset] = 0
        for offset in range(dst_offset + total_bytes_copy, double_channel_test_offset, 1):
            if dst_buffer[offset] != 0:
                print(f"A should not be modified, dst_buffer[{hex(offset)}]={hex(dst_buffer[offset])}")
                raise SystemExit
            
        if double_channel_test_offset != 0:
            for offset in range(double_channel_test_offset, double_channel_test_offset + dst_offset, 1):
                if dst_buffer[offset] != 0:
                    print(f"B should not be modified, dst_buffer[{hex(offset)}]={hex(dst_buffer[offset])}")
                    raise SystemExit
            for (s_offset, d_offset) in zip(range(double_channel_test_offset + src_offset, double_channel_test_offset + src_offset + total_bytes_copy, 1), range(double_channel_test_offset + dst_offset, double_channel_test_offset + dst_offset + total_bytes_copy, 1)):
                if dst_buffer[d_offset] != src_buffer[s_offset]:
                    print(f"B not match, dst_buffer[{hex(d_offset)}]={hex(dst_buffer[d_offset])}, src_buffer[{hex(s_offset)}]={hex(src_buffer[s_offset])}")
                    raise SystemExit
                mem[1024*1024 + d_offset] = 0
            for offset in range(double_channel_test_offset + dst_offset + total_bytes_copy, 1024 * 1024, 1):
                if dst_buffer[offset] != 0:
                    print(f"B should not be modified, dst_buffer[{hex(offset)}]={hex(dst_buffer[offset])}")
                    raise SystemExit
            
        
            
        print("pass" + "\n" * 10)


@cocotb.test(timeout_time=10000000, timeout_unit="ns")
async def test_entry(dut):
    tb = BdmaLoopTb(dut)
    await tb.gen_reset()

    await tb.rc.enumerate()
    dev = tb.rc.find_device(tb.dev.functions[0].pcie_id)

    await dev.enable_device()
    await dev.set_master()

    tb.root_port.downstream_port.link_delay_steps = 428*1000

    mem = tb.rc.mem_pool.alloc_region(2*1024*1024)
    for idx in range(32768):
        mem[idx*2:idx*2+2] = idx.to_bytes(2, "little")
        # mem[10:15] = b'world'

    await Timer(5000, "ns")

    await throughput_test(dut, dev, mem)
    # await correct_test(dut, dev, mem)




def test_dma():
    dut = "mkRawTestDmaController"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v")
    ]

    sim_build = os.path.join(tests_dir, "sim_build", dut)

    cocotb_test.simulator.run(
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        timescale="1ns/1ps",
        sim_build=sim_build
    )


if __name__ == "__main__":
    test_dma()
