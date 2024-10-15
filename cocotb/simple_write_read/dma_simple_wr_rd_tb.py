import os
import random

import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

import cocotb_test.simulator

from bdmatb import BdmaSimpleTb

tests_dir = os.path.dirname(__file__)
rtl_dir = tests_dir

@cocotb.test(timeout_time=10000000, timeout_unit="ns")   
async def bar_test(dut):
    tb = BdmaSimpleTb(dut)
    await tb.gen_reset()
    
    await tb.rc.enumerate()
    dev = tb.rc.find_device(tb.dev.functions[0].pcie_id)
    
    await dev.enable_device()
    await dev.set_master()
    
    dev_bar0 = dev.bar_window[0]
    addr = 0x12345678
    length = 0xffff
    isWrite = True
    addrLo = addr & 0xFFFFFFFF
    addrHi = (addr >> 32) & 0xFFFFFFFF
    base_addr = 0
    await dev_bar0.write(base_addr + 1, addrLo.to_bytes(4, byteorder='big', signed=False))
    await dev_bar0.write(base_addr + 2, addrHi.to_bytes(4, byteorder='big', signed=False))
    await dev_bar0.write(base_addr + 3, length.to_bytes(4, byteorder='big', signed=False))
    await dev_bar0.write(base_addr, int(isWrite).to_bytes(4, byteorder='big', signed=False))
    
    await Timer(500, units='ns')
def test_dma():
    dut = "mkRawSimpleDmaController"
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