#!/usr/bin/env python
import os
import random

import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

import cocotb_test.simulator

import sys
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from bdmatb import BdmaBypassTb

#  class TB architecture
#  --------------        -------------         ----------- 
# | Root Complex | <->  | End Pointer |  <->  | Dut(DMAC) |         
#  --------------        -------------         -----------

def gen_pseudo_data(addr, length):
    start = int(addr / 4)
    data = start.to_bytes(4, byteorder='little', signed=False)
    for i in range(1, int(length/4)):
        data = data + (start + i).to_bytes(4, byteorder='little', signed=False)
    return data

async def stress_random_write_test(pcie_tb, dma_channel, mem, n):
    addr = 0
    length = 0
    for _ in range(n):
        length = pcie_tb.gen_random_aligned_len()
        data = gen_pseudo_data(addr, length)
        await pcie_tb.run_single_write_once(dma_channel, addr, data)
        addr = int((addr + length)/4) * 4
    return addr

async def run_stress_write(pcie_tb, mem):
    n = 10
    end = await stress_random_write_test(pcie_tb, 0, mem, n)
    await Timer(2048 * 2048)
    for i in range(int(end/4)):
        assert i == int.from_bytes(mem[i*4:(i+1)*4], byteorder='little', signed=False)
            
@cocotb.test(timeout_time=100000000, timeout_unit="ns")
async def step_random_write_test(dut):

    tb = BdmaBypassTb(dut)
    await tb.gen_reset()
    
    await tb.rc.enumerate()
    dev = tb.rc.find_device(tb.dev.functions[0].pcie_id)
    
    await dev.enable_device()
    await dev.set_master()
    
    mem = tb.rc.mem_pool.alloc_region(1024*1024)
    
    await run_stress_write(tb, mem)
    

tests_dir = os.path.dirname(__file__)
rtl_dir = tests_dir
bdmatb_dir = os.path.dirname(tests_dir)


def test_dma():
    dut = "mkRawBypassDmaController"
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